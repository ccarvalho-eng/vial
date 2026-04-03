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
    projects = Projects.list_projects()

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
      |> assign(:editing_test_case_id, nil)
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
    {:noreply, assign(socket, :selected_version_id, version_id)}
  end

  @impl Phoenix.LiveView
  def handle_event("select_provider", %{"provider_id" => provider_id}, socket) do
    {:noreply, assign(socket, :selected_provider_id, provider_id)}
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

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_test_case", _params, socket) do
    # This event is needed for LiveView uploads to work
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save_test_case", params, socket) do
    id = params["id"]
    test_case = Evals.get_test_case!(id)

    # Parse variables from params
    variables =
      params
      |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "var_value_") end)
      |> Enum.map(fn {"var_value_" <> key, value} -> {key, value} end)
      |> Map.new()

    # Parse assertions based on edit mode
    edit_mode = Map.get(socket.assigns.assertion_edit_mode, id, :visual)

    case parse_assertions(edit_mode, params) do
      {:ok, assertions} ->
        attrs = %{
          variable_values: variables,
          assertions: assertions
        }

        update_test_case_with_attrs(socket, test_case, attrs, params)

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
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
  def handle_event("run_suite", _params, socket) do
    # Prevent concurrent runs
    if socket.assigns.running do
      {:noreply, put_flash(socket, :error, "Suite is already running")}
    else
      # Use the stored selections instead of params
      version_id = socket.assigns.selected_version_id
      provider_id = socket.assigns.selected_provider_id

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
    assertion_indices =
      params
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "assertion_type_"))
      |> Enum.map(fn "assertion_type_" <> idx -> String.to_integer(idx) end)
      |> Enum.sort()

    assertions =
      Enum.map(assertion_indices, fn idx ->
        type = params["assertion_type_#{idx}"]

        if type == "json_field" do
          %{
            "type" => type,
            "field" => params["assertion_field_#{idx}"],
            "expected" => params["assertion_expected_#{idx}"]
          }
        else
          %{
            "type" => type,
            "value" => params["assertion_value_#{idx}"]
          }
        end
      end)

    {:ok, assertions}
  end

  defp update_test_case_with_attrs(socket, test_case, attrs, _params) do
    case Evals.update_test_case(test_case, attrs) do
      {:ok, _test_case} ->
        # Handle uploaded documents and collect results
        {successful_uploads, failed_uploads} =
          consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
            {:ok, data} = File.read(path)

            # Validate file content matches claimed type
            case FileValidation.validate(data, entry.client_type) do
              :ok ->
                case Evals.create_test_case_document(%{
                       test_case_id: test_case.id,
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

              {:error, reason} ->
                {:ok, {:failed, entry.client_name, reason}}
            end
          end)
          |> Enum.split_with(fn
            {:success, _} -> true
            _ -> false
          end)

        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        socket =
          socket
          |> assign(:suite, suite)
          |> assign(:editing_test_case_id, nil)
          |> assign(:editing_assertions, nil)

        # Build appropriate flash message based on results
        socket =
          cond do
            # All uploads failed
            failed_uploads != [] and successful_uploads == [] ->
              failed_files =
                Enum.map_join(failed_uploads, ", ", fn {:failed, name, reason} ->
                  "#{name} (#{reason})"
                end)

              put_flash(
                socket,
                :error,
                "Test case updated but document uploads failed: #{failed_files}"
              )

            # Some uploads failed
            failed_uploads != [] ->
              failed_count = length(failed_uploads)
              success_count = length(successful_uploads)

              put_flash(
                socket,
                :warning,
                "Test case updated with #{success_count} document(s), but #{failed_count} failed validation"
              )

            # All uploads succeeded
            successful_uploads != [] ->
              put_flash(
                socket,
                :info,
                "Test case updated with #{length(successful_uploads)} document(s)"
              )

            # No uploads
            true ->
              put_flash(socket, :info, "Test case updated successfully")
          end

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update test case")}
    end
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
end
