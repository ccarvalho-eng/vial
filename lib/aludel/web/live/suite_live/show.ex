defmodule Aludel.Web.SuiteLive.Show do
  @moduledoc """
  LiveView for displaying a single evaluation suite.

  Shows suite details, test cases, and allows running the suite
  against a specific prompt version and provider.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
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
      |> assign(:providers, providers)
      |> assign(:suite_runs, suite_runs)
      |> assign(:running, false)
      |> assign(:selected_version_id, default_version_id)
      |> assign(:selected_provider_id, default_provider_id)
      |> assign(:editing_test_case_id, nil)

    {:noreply, socket}
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

    # Parse assertions from params
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

    attrs = %{
      variable_values: variables,
      assertions: assertions
    }

    case Evals.update_test_case(test_case, attrs) do
      {:ok, _test_case} ->
        # Handle uploaded documents
        uploaded_files =
          consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
            {:ok, data} = File.read(path)

            # Validate file content matches claimed type
            case validate_file_content(data, entry.client_type) do
              :ok ->
                {:ok, _doc} =
                  Evals.create_test_case_document(%{
                    test_case_id: test_case.id,
                    filename: entry.client_name,
                    content_type: entry.client_type,
                    data: data,
                    size_bytes: entry.client_size
                  })

                {:ok, entry.client_name}

              {:error, reason} ->
                {:postpone, reason}
            end
          end)

        suite = Evals.get_suite_with_test_cases_and_prompt!(socket.assigns.suite.id)

        flash_msg =
          if uploaded_files == [] do
            "Test case updated successfully"
          else
            "Test case updated with #{length(uploaded_files)} document(s)"
          end

        {:noreply,
         socket
         |> assign(:suite, suite)
         |> assign(:editing_test_case_id, nil)
         |> assign(:editing_assertions, nil)
         |> put_flash(:info, flash_msg)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update test case")}
    end
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

      Task.Supervisor.start_child(Aludel.TaskSupervisor, fn ->
        version = Prompts.get_prompt_version!(version_id)
        provider = Providers.get_provider!(provider_id)
        suite = Evals.get_suite_with_test_cases!(suite_id)

        result = Evals.execute_suite(suite, version, provider)
        send(pid, {:suite_completed, result})
      end)

      {:noreply, assign(socket, :running, true)}
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

  # Validate file content matches claimed MIME type using magic bytes
  defp validate_file_content(data, content_type) do
    # Check magic bytes (file signatures) for common types
    magic_bytes = :binary.part(data, 0, min(byte_size(data), 8))

    case {content_type, magic_bytes} do
      # PDF files start with %PDF
      {"application/pdf", <<"%PDF", _::binary>>} ->
        :ok

      # PNG files
      {"image/png", <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>} ->
        :ok

      # JPEG files
      {"image/jpeg", <<0xFF, 0xD8, 0xFF, _::binary>>} ->
        :ok

      # JSON (starts with { or [)
      {"application/json", <<char, _::binary>>} when char in [?{, ?\[, 32, 9, 10, 13] ->
        # Validate it's actually valid JSON
        case Jason.decode(data) do
          {:ok, _} -> :ok
          {:error, _} -> {:error, "Invalid JSON file"}
        end

      # CSV and TXT - allow any text content (no reliable magic bytes)
      {ct, _} when ct in ["text/csv", "text/plain"] ->
        # Just verify it's valid UTF-8
        if String.valid?(data) do
          :ok
        else
          {:error, "File is not valid UTF-8 text"}
        end

      # Mismatch between claimed type and actual content
      {claimed, _} ->
        {:error, "File content does not match type #{claimed}"}
    end
  end
end
