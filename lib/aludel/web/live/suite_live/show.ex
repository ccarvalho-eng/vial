defmodule Aludel.Web.SuiteLive.Show do
  @moduledoc """
  LiveView for displaying a single evaluation suite.

  Shows suite details, test cases, and allows running the suite
  against a specific prompt version and provider.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.Evals.AssertionParser
  alias Aludel.Evals.DocumentIngestion
  alias Aludel.Evals.TestCaseEditor
  alias Aludel.Projects
  alias Aludel.Prompts
  alias Aludel.Providers

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    suite = Evals.get_suite_with_test_cases_and_prompt!(id)
    prompt = Prompts.get_prompt_with_versions!(suite.prompt_id)
    providers = Providers.list_providers()
    all_prompts = Prompts.list_prompts()
    projects = Projects.list_projects(type: :suite)

    # Load existing suite runs
    suite_runs = Evals.list_suite_runs_for_suite_with_associations(id)

    # Set default selections to first version and first provider
    default_version_id = List.first(prompt.versions) |> then(&if &1, do: &1.id, else: nil)
    default_provider_id = List.first(providers) |> then(&if &1, do: &1.id, else: nil)

    socket =
      socket
      |> assign(:page_title, suite.name)
      |> assign(:suite, suite)
      |> assign(:prompt, prompt)
      |> assign(:selected_prompt_version, selected_prompt_version(prompt, default_version_id))
      |> assign(:all_prompts, all_prompts)
      |> assign(:projects, projects)
      |> assign(:providers, providers)
      |> assign(:suite_runs, suite_runs)
      |> assign(:running, false)
      |> assign(:run_task_monitor_ref, nil)
      |> assign(:selected_version_id, default_version_id)
      |> assign(:selected_provider_id, default_provider_id)
      |> assign(:run_suite_form, build_run_suite_form(default_version_id, default_provider_id))
      |> assign(:editing_test_case_id, nil)
      |> assign(:test_case_form, nil)
      |> assign(:editing_test_case_params, nil)
      |> assign(:editing_suite_metadata, false)
      |> assign(:assertion_edit_mode, %{})

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("edit_suite_metadata", _params, socket) do
    changeset = Evals.change_suite(socket.assigns.suite)

    {:noreply,
     socket
     |> assign(:editing_suite_metadata, true)
     |> assign(:suite_form, to_form(changeset))}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_edit_suite_metadata", _params, socket) do
    {:noreply, assign(socket, :editing_suite_metadata, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_suite_metadata", %{"suite" => suite_params}, socket) do
    changeset =
      socket.assigns.suite
      |> Evals.change_suite(suite_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :suite_form, to_form(changeset))}
  end

  @impl Phoenix.LiveView
  def handle_event("save_suite_metadata", %{"suite" => suite_params}, socket) do
    # Handle empty string as nil for optional project_id
    suite_params =
      Map.update(suite_params, "project_id", nil, fn
        "" -> nil
        val -> val
      end)

    case Evals.update_suite(socket.assigns.suite, suite_params) do
      {:ok, suite} ->
        prompt = Prompts.get_prompt_with_versions!(suite.prompt_id)
        default_version_id = List.first(prompt.versions) |> then(&if &1, do: &1.id, else: nil)

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> assign(:prompt, prompt)
         |> assign(:selected_version_id, default_version_id)
         |> assign(:selected_prompt_version, selected_prompt_version(prompt, default_version_id))
         |> assign(:page_title, suite.name)
         |> assign(
           :run_suite_form,
           build_run_suite_form(default_version_id, socket.assigns.selected_provider_id)
         )
         |> assign(:editing_suite_metadata, false)
         |> put_flash(:info, "Suite updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :suite_form, to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select_version", %{"version_id" => version_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_version_id, version_id)
     |> assign(
       :selected_prompt_version,
       selected_prompt_version(socket.assigns.prompt, version_id)
     )
     |> assign(
       :run_suite_form,
       build_run_suite_form(version_id, socket.assigns.selected_provider_id)
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("select_provider", %{"provider_id" => provider_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_provider_id, provider_id)
     |> assign(
       :run_suite_form,
       build_run_suite_form(socket.assigns.selected_version_id, provider_id)
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_run_suite", %{"run_suite" => run_suite_params}, socket) do
    version_id = Map.get(run_suite_params, "version_id")
    provider_id = Map.get(run_suite_params, "provider_id")

    {:noreply,
     socket
     |> assign(:selected_version_id, version_id)
     |> assign(:selected_provider_id, provider_id)
     |> assign(
       :selected_prompt_version,
       selected_prompt_version(socket.assigns.prompt, version_id)
     )
     |> assign(:run_suite_form, to_form(run_suite_params, as: :run_suite))}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_assertion_mode", %{"id" => id}, socket) do
    current_mode = Map.get(socket.assigns.assertion_edit_mode, id, :visual)
    new_mode = if current_mode == :visual, do: :json, else: :visual
    new_modes = Map.put(socket.assigns.assertion_edit_mode, id, new_mode)
    {:noreply, assign(socket, :assertion_edit_mode, new_modes)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_assertion", %{"id" => _id}, socket) do
    new_assertions = socket.assigns.editing_assertions ++ [%{"type" => "contains", "value" => ""}]
    {:noreply, assign(socket, :editing_assertions, new_assertions)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_assertion", %{"index" => index_str, "id" => _id}, socket) do
    index = String.to_integer(index_str)
    new_assertions = List.delete_at(socket.assigns.editing_assertions, index)
    {:noreply, assign(socket, :editing_assertions, new_assertions)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_test_case", _params, socket) do
    case TestCaseEditor.create_test_case(socket.assigns.suite.id, socket.assigns.prompt) do
      {:ok, _test_case} ->
        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> put_flash(:info, "Test case created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create test case")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("edit_test_case", %{"id" => id}, socket) do
    test_case = Evals.get_test_case!(id)
    form_params = TestCaseEditor.build_form_params(test_case)

    socket =
      socket
      |> assign(:editing_test_case_id, id)
      |> assign(:editing_assertions, test_case.assertions)
      |> assign(:editing_test_case_params, form_params)
      |> assign(:test_case_form, to_form(TestCaseEditor.change_form(form_params), as: :test_case))
      |> allow_upload(:documents,
        accept: ~w(.pdf .png .jpg .jpeg .csv .json .txt),
        max_entries: 5,
        max_file_size: 10_000_000
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing_test_case_id, nil)
      |> assign(:editing_assertions, nil)
      |> assign(:test_case_form, nil)
      |> assign(:editing_test_case_params, nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_test_case", %{"test_case" => test_case_params}, socket) do
    edit_mode = Map.get(socket.assigns.assertion_edit_mode, test_case_params["id"], :visual)

    socket =
      socket
      |> assign(:editing_test_case_params, test_case_params)

    socket =
      if edit_mode == :visual do
        case AssertionParser.parse(:visual, test_case_params) do
          {:ok, assertions} ->
            socket
            |> assign(:editing_assertions, assertions)
            |> assign(
              :test_case_form,
              to_form(TestCaseEditor.change_form(test_case_params, action: :validate),
                as: :test_case
              )
            )

          {:error, message} ->
            assign(
              socket,
              :test_case_form,
              to_form(
                TestCaseEditor.change_form(
                  test_case_params,
                  action: :validate,
                  assertion_error: message
                ),
                as: :test_case
              )
            )
        end
      else
        assign(
          socket,
          :test_case_form,
          to_form(TestCaseEditor.change_form(test_case_params, action: :validate), as: :test_case)
        )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save_test_case", %{"test_case" => test_case_params}, socket) do
    id = test_case_params["id"]
    test_case = Evals.get_test_case!(id)
    edit_mode = Map.get(socket.assigns.assertion_edit_mode, id, :visual)

    case TestCaseEditor.update_test_case(test_case, test_case_params, edit_mode) do
      {:ok, _test_case} ->
        {successful_uploads, failed_uploads} = handle_test_case_uploads(socket, test_case)
        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        socket =
          socket
          |> assign(:suite, suite)
          |> assign(:editing_test_case_id, nil)
          |> assign(:editing_assertions, nil)
          |> assign(:test_case_form, nil)
          |> assign(:editing_test_case_params, nil)

        {:noreply, put_upload_flash(socket, successful_uploads, failed_uploads)}

      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(
           :test_case_form,
           to_form(
             TestCaseEditor.change_form(
               test_case_params,
               action: :validate,
               assertion_error: message
             ),
             as: :test_case
           )
         )
         |> assign(:editing_test_case_params, test_case_params)
         |> put_flash(:error, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update test case")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_document", %{"doc-id" => doc_id, "id" => _test_case_id}, socket) do
    document = Evals.get_test_case_document!(doc_id)

    case Evals.delete_test_case_document(document) do
      {:ok, _} ->
        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> put_flash(:info, "Document deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete document")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_test_case", %{"id" => id}, socket) do
    test_case = Evals.get_test_case!(id)

    case Evals.delete_test_case(test_case) do
      {:ok, _} ->
        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> put_flash(:info, "Test case deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete test case")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("run_suite", %{"run_suite" => run_suite_params}, socket) do
    # Prevent concurrent runs
    if socket.assigns.running do
      {:noreply, put_flash(socket, :error, "Suite is already running")}
    else
      version_id = Map.get(run_suite_params, "version_id", socket.assigns.selected_version_id)
      provider_id = Map.get(run_suite_params, "provider_id", socket.assigns.selected_provider_id)
      {:noreply, start_suite_execution(socket, version_id, provider_id)}
    end
  end

  defp handle_test_case_uploads(socket, test_case) do
    socket
    |> consume_uploaded_entries(:documents, fn %{path: path}, entry ->
      {:ok, DocumentIngestion.ingest(path, entry, test_case.id)}
    end)
    |> Enum.split_with(&successful_upload?/1)
  end

  defp successful_upload?({:success, _}), do: true
  defp successful_upload?(_), do: false

  defp put_upload_flash(socket, successful_uploads, failed_uploads)
       when failed_uploads != [] and successful_uploads == [] do
    failed_files =
      Enum.map_join(failed_uploads, ", ", fn {:failed, name, reason} ->
        "#{name} (#{reason})"
      end)

    put_flash(
      socket,
      :error,
      "Test case updated but document uploads failed: #{failed_files}"
    )
  end

  defp put_upload_flash(socket, successful_uploads, failed_uploads) when failed_uploads != [] do
    failed_count = length(failed_uploads)
    success_count = length(successful_uploads)

    put_flash(
      socket,
      :warning,
      "Test case updated with #{success_count} document(s), but #{failed_count} failed validation"
    )
  end

  defp put_upload_flash(socket, successful_uploads, _failed_uploads)
       when successful_uploads != [] do
    put_flash(
      socket,
      :info,
      "Test case updated with #{length(successful_uploads)} document(s)"
    )
  end

  defp put_upload_flash(socket, _successful_uploads, _failed_uploads) do
    put_flash(socket, :info, "Test case updated successfully")
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_completed, {:ok, suite_run}}, socket) do
    # Suite run comes from execute_suite which returns it after insert,
    # so we need to preload associations here since it's not from a context query
    suite_run = Evals.reload_suite_run_with_associations(suite_run)

    {:noreply,
     socket
     |> assign(:suite_runs, [suite_run | socket.assigns.suite_runs])
     |> clear_run_task_state()
     |> put_flash(:info, "Suite executed successfully")}
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_completed, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> clear_run_task_state()
     |> put_flash(:error, suite_execution_error_message(reason))}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:DOWN, monitor_ref, :process, _pid, reason},
        %{assigns: %{run_task_monitor_ref: monitor_ref}} = socket
      ) do
    if reason == :normal do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> clear_run_task_state()
       |> put_flash(:error, "Suite execution crashed before completion")}
    end
  end

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 ->
        "just now"

      diff < 3600 ->
        minutes = div(diff, 60)
        "#{minutes} #{if minutes == 1, do: "minute", else: "minutes"} ago"

      diff < 86_400 ->
        hours = div(diff, 3600)
        "#{hours} #{if hours == 1, do: "hour", else: "hours"} ago"

      diff < 604_800 ->
        days = div(diff, 86_400)
        "#{days} #{if days == 1, do: "day", else: "days"} ago"

      true ->
        Calendar.strftime(datetime, "%B %d, %Y")
    end
  end

  defp build_run_suite_form(version_id, provider_id) do
    to_form(
      %{
        "version_id" => version_id,
        "provider_id" => provider_id
      },
      as: :run_suite
    )
  end

  defp selected_prompt_version(%{versions: versions}, version_id) when is_list(versions) do
    Enum.find(versions, List.first(versions), fn version ->
      to_string(version.id) == to_string(version_id)
    end)
  end

  defp clear_run_task_state(socket) do
    case socket.assigns.run_task_monitor_ref do
      nil ->
        assign(socket, :running, false)

      monitor_ref ->
        Process.demonitor(monitor_ref, [:flush])

        socket
        |> assign(:run_task_monitor_ref, nil)
        |> assign(:running, false)
    end
  end

  defp start_suite_execution(socket, version_id, provider_id) do
    case Evals.launch_suite_execution(
           self(),
           socket.assigns.suite.id,
           version_id,
           provider_id
         ) do
      {:ok, monitor_ref} ->
        socket
        |> assign(:run_task_monitor_ref, monitor_ref)
        |> assign(:running, true)

      {:error, _reason} ->
        put_flash(socket, :error, "Failed to start suite execution")
    end
  end

  defp suite_execution_error_message(:suite_not_found),
    do: "Failed to execute suite: suite not found"

  defp suite_execution_error_message(:prompt_version_not_found),
    do: "Failed to execute suite: prompt version not found"

  defp suite_execution_error_message(:provider_not_found),
    do: "Failed to execute suite: provider not found"

  defp suite_execution_error_message({:execution_failed, detail}),
    do: "Failed to execute suite: #{format_execution_error_detail(detail)}"

  defp suite_execution_error_message(_reason), do: "Failed to execute suite"

  defp format_execution_error_detail(detail) when is_binary(detail), do: detail
  defp format_execution_error_detail(detail), do: inspect(detail)
end
