defmodule Aludel.Web.SuiteLive.Show do
  @moduledoc """
  LiveView for displaying a single evaluation suite.

  Shows suite details, test cases, and allows running the suite
  against a specific prompt version and provider.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.FileValidation
  alias Aludel.Projects
  alias Aludel.Prompts
  alias Aludel.Providers
  alias Aludel.TaskSupervisor

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
      |> assign(:all_prompts, all_prompts)
      |> assign(:projects, projects)
      |> assign(:providers, providers)
      |> assign(:suite_runs, suite_runs)
      |> assign(:running, false)
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

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> assign(:prompt, prompt)
         |> assign(:page_title, suite.name)
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
    # Extract variables from prompt template
    template =
      socket.assigns.prompt.versions |> List.first() |> then(&if &1, do: &1.template, else: "")

    variables = extract_variables(template)
    variable_values = Map.new(variables, fn var -> {var, ""} end)

    # Create new test case
    case Evals.create_test_case(%{
           suite_id: socket.assigns.suite.id,
           variable_values: variable_values,
           assertions: [%{"type" => "contains", "value" => ""}]
         }) do
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

    socket =
      socket
      |> assign(:editing_test_case_id, id)
      |> assign(:editing_assertions, test_case.assertions)
      |> assign(:editing_test_case_params, build_test_case_form_params(test_case))
      |> assign(:test_case_form, to_form(build_test_case_form_params(test_case), as: :test_case))
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
      |> assign(:test_case_form, to_form(test_case_params, as: :test_case))
      |> assign(:editing_test_case_params, test_case_params)

    socket =
      if edit_mode == :visual do
        {:ok, assertions} = parse_assertions(:visual, test_case_params)
        assign(socket, :editing_assertions, assertions)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save_test_case", %{"test_case" => test_case_params}, socket) do
    id = test_case_params["id"]
    test_case = Evals.get_test_case!(id)
    variables = Map.get(test_case_params, "variable_values", %{})

    # Parse assertions based on edit mode
    edit_mode = Map.get(socket.assigns.assertion_edit_mode, id, :visual)

    case parse_assertions(edit_mode, test_case_params) do
      {:ok, assertions} ->
        attrs = %{
          variable_values: variables,
          assertions: assertions
        }

        update_test_case_with_attrs(socket, test_case, attrs, test_case_params)

      {:error, message} ->
        {:noreply,
         socket
         |> assign(:test_case_form, to_form(test_case_params, as: :test_case))
         |> assign(:editing_test_case_params, test_case_params)
         |> put_flash(:error, message)}
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

      # Start async execution
      pid = self()
      suite_id = socket.assigns.suite.id

      Task.Supervisor.start_child(TaskSupervisor, fn ->
        version = Prompts.get_prompt_version!(version_id)
        provider = Providers.get_provider!(provider_id)
        suite = Evals.get_suite_with_test_cases!(suite_id)

        result = Evals.execute_suite(suite, version, provider)
        send(pid, {:suite_completed, result})
      end)

      {:noreply, assign(socket, :running, true)}
    end
  end

  defp parse_assertions(:json, params) do
    case Jason.decode(params["assertions_json"] || "[]") do
      {:ok, json_assertions} when is_list(json_assertions) ->
        case validate_assertions(json_assertions) do
          :ok -> {:ok, json_assertions}
          {:error, _} = error -> error
        end

      {:ok, _} ->
        {:error, "Invalid JSON: assertions must be a list"}

      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON syntax in assertions"}
    end
  end

  defp parse_assertions(:visual, params) do
    assertion_params = normalize_assertion_params(params["assertions"] || %{})

    assertion_indices =
      assertion_params
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "assertion_type_"))
      |> Enum.map(fn "assertion_type_" <> idx -> String.to_integer(idx) end)
      |> Enum.sort()

    assertions =
      Enum.map(assertion_indices, fn idx ->
        type = Map.get(assertion_params, "assertion_type_#{idx}")

        if type == "json_field" do
          %{
            "type" => type,
            "field" => Map.get(assertion_params, "assertion_field_#{idx}"),
            "expected" => Map.get(assertion_params, "assertion_expected_#{idx}")
          }
        else
          %{
            "type" => type,
            "value" => Map.get(assertion_params, "assertion_value_#{idx}")
          }
        end
      end)

    {:ok, assertions}
  end

  defp update_test_case_with_attrs(socket, test_case, attrs, _params) do
    case Evals.update_test_case(test_case, attrs) do
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

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update test case")}
    end
  end

  defp handle_test_case_uploads(socket, test_case) do
    socket
    |> consume_uploaded_entries(:documents, fn %{path: path}, entry ->
      process_test_case_upload(path, entry, test_case.id)
    end)
    |> Enum.split_with(&successful_upload?/1)
  end

  defp process_test_case_upload(path, entry, test_case_id) do
    {:ok, data} = File.read(path)

    case FileValidation.validate(data, entry.client_type) do
      :ok -> persist_test_case_document(entry, data, test_case_id)
      {:error, reason} -> {:ok, {:failed, entry.client_name, reason}}
    end
  end

  defp persist_test_case_document(entry, data, test_case_id) do
    case Evals.create_test_case_document(%{
           test_case_id: test_case_id,
           filename: entry.client_name,
           content_type: entry.client_type,
           data: data,
           size_bytes: entry.client_size
         }) do
      {:ok, _doc} ->
        {:ok, {:success, entry.client_name}}

      {:error, _changeset} ->
        {:ok, {:failed, entry.client_name, "Database error"}}
    end
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
     |> assign(:running, false)
     |> put_flash(:info, "Suite executed successfully")}
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_completed, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(:running, false)
     |> put_flash(:error, "Failed to execute suite")}
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

  defp extract_variables(template) do
    ~r/\{\{([^}]+)\}\}/
    |> Regex.scan(template)
    |> Enum.map(fn [_, var] -> String.trim(var) end)
    |> Enum.uniq()
  end

  defp validate_assertions(assertions) do
    valid_types = ["contains", "not_contains", "regex", "exact_match", "json_field"]

    assertions
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {assertion, idx}, _acc ->
      type = Map.get(assertion, "type")

      cond do
        type not in valid_types ->
          {:halt,
           {:error,
            "Invalid assertion type at index #{idx}: #{inspect(type)}. Must be one of: #{Enum.join(valid_types, ", ")}"}}

        type == "json_field" and
            (not Map.has_key?(assertion, "field") or not Map.has_key?(assertion, "expected")) ->
          {:halt,
           {:error,
            "Assertion at index #{idx}: json_field type requires 'field' and 'expected' fields"}}

        type != "json_field" and not Map.has_key?(assertion, "value") ->
          {:halt, {:error, "Assertion at index #{idx}: #{type} type requires 'value' field"}}

        true ->
          {:cont, :ok}
      end
    end)
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

  defp build_test_case_form_params(test_case) do
    %{
      "id" => test_case.id,
      "variable_values" => test_case.variable_values || %{},
      "assertions_json" => Jason.encode!(test_case.assertions || [], pretty: true),
      "assertions" => build_assertion_params(test_case.assertions || [])
    }
  end

  defp build_assertion_params(assertions) do
    assertions
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {assertion, idx}, acc ->
      acc
      |> Map.put("assertion_type_#{idx}", assertion["type"])
      |> maybe_put_assertion_value(idx, assertion)
    end)
  end

  defp maybe_put_assertion_value(params, idx, %{"type" => "json_field"} = assertion) do
    params
    |> Map.put("assertion_field_#{idx}", assertion["field"] || "")
    |> Map.put("assertion_expected_#{idx}", assertion["expected"] || "")
  end

  defp maybe_put_assertion_value(params, idx, assertion) do
    Map.put(params, "assertion_value_#{idx}", assertion["value"] || "")
  end

  defp normalize_assertion_params(params) when is_map(params), do: params
  defp normalize_assertion_params(params) when is_list(params), do: Map.new(params)
  defp normalize_assertion_params(_params), do: %{}
end
