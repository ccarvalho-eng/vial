defmodule Aludel.Web.SuiteLive.New do
  @moduledoc """
  LiveView for creating a new evaluation suite.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.Evals.AssertionParser
  alias Aludel.Evals.Suite
  alias Aludel.Projects
  alias Aludel.Prompts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"suite" => suite_params}, socket) do
    selected_prompt = find_selected_prompt(socket.assigns.prompts, suite_params["prompt_id"])

    changeset =
      socket.assigns.suite
      |> Evals.change_suite(Map.drop(suite_params, ["test_cases"]))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:suite, Ecto.Changeset.apply_changes(changeset))
     |> assign(:form, to_form(changeset))
     |> assign(:selected_prompt, selected_prompt)
     |> assign(
       :test_cases,
       merge_test_cases_from_params(suite_params, socket.assigns.test_cases, selected_prompt)
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("add_test_case", _params, socket) do
    # Extract variables from selected prompt
    variable_values =
      case socket.assigns.selected_prompt do
        %{versions: [%{template: template} | _]} ->
          variables = extract_variables(template)
          Map.new(variables, fn var -> {var, ""} end)

        _ ->
          %{}
      end

    new_test_case = %{
      id: generate_id(),
      assertions: [],
      variable_values: variable_values
    }

    test_cases = socket.assigns.test_cases ++ [new_test_case]
    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_test_case", %{"id" => id}, socket) do
    test_cases = Enum.reject(socket.assigns.test_cases, fn tc -> tc.id == id end)
    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_assertion_mode", %{"id" => id}, socket) do
    current_mode = Map.get(socket.assigns.assertion_edit_mode, id, :visual)
    new_mode = if current_mode == :visual, do: :json, else: :visual
    new_modes = Map.put(socket.assigns.assertion_edit_mode, id, new_mode)
    {:noreply, assign(socket, :assertion_edit_mode, new_modes)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_assertion", %{"id" => id}, socket) do
    test_cases =
      Enum.map(socket.assigns.test_cases, fn tc ->
        if tc.id == id do
          new_assertion = %{"type" => "contains", "value" => ""}
          %{tc | assertions: (tc[:assertions] || []) ++ [new_assertion]}
        else
          tc
        end
      end)

    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_assertion", %{"id" => id, "index" => index_str}, socket) do
    index = String.to_integer(index_str)

    test_cases =
      Enum.map(socket.assigns.test_cases, fn tc ->
        if tc.id == id do
          assertions = tc[:assertions] || []
          %{tc | assertions: List.delete_at(assertions, index)}
        else
          tc
        end
      end)

    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"suite" => suite_params}, socket) do
    save_suite(socket, socket.assigns.live_action, suite_params)
  end

  defp apply_action(socket, :new, params) do
    project_id = Map.get(params, "project_id")
    initial_data = if project_id, do: %{"project_id" => project_id}, else: %{}
    suite = %Suite{project_id: project_id}
    changeset = Evals.change_suite(suite, initial_data)
    prompts = Prompts.list_prompts_with_versions()
    projects = Projects.list_projects(type: :suite)

    socket
    |> assign(:page_title, "New Suite")
    |> assign(:suite, suite)
    |> assign(:form, to_form(changeset))
    |> assign(:prompts, prompts)
    |> assign(:projects, projects)
    |> assign(:test_cases, [])
    |> assign(:selected_prompt, nil)
    |> assign(:assertion_edit_mode, %{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    suite = Evals.get_suite_with_test_cases_and_prompt!(id)
    changeset = Evals.change_suite(suite)
    prompts = Prompts.list_prompts_with_versions()
    projects = Projects.list_projects(type: :suite)

    # Get the selected prompt if suite has one
    selected_prompt =
      if suite.prompt_id do
        Enum.find(prompts, fn p -> p.id == suite.prompt_id end)
      else
        nil
      end

    # Convert existing test cases to the format expected by the form
    test_cases =
      Enum.map(suite.test_cases, fn tc ->
        %{
          id: tc.id,
          variable_values: tc.variable_values,
          assertions: tc.assertions
        }
      end)

    socket
    |> assign(:page_title, "Edit Suite")
    |> assign(:suite, suite)
    |> assign(:form, to_form(changeset))
    |> assign(:prompts, prompts)
    |> assign(:projects, projects)
    |> assign(:test_cases, test_cases)
    |> assign(:selected_prompt, selected_prompt)
    |> assign(:assertion_edit_mode, %{})
  end

  defp save_suite(socket, :new, suite_params) do
    case validate_test_cases(suite_params) do
      :ok ->
        case create_suite_with_test_cases(suite_params) do
          {:ok, suite} ->
            {:noreply,
             socket
             |> put_flash(:info, "Suite created successfully")
             |> push_navigate(to: aludel_path("suites/#{suite.id}"))}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> assign(
               :test_cases,
               merge_test_cases_from_params(
                 suite_params,
                 socket.assigns.test_cases,
                 socket.assigns.selected_prompt
               )
             )}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp save_suite(socket, :edit, suite_params) do
    case validate_test_cases(suite_params) do
      :ok ->
        case update_suite_with_test_cases(socket.assigns.suite, suite_params) do
          {:ok, suite} ->
            {:noreply,
             socket
             |> put_flash(:info, "Suite updated successfully")
             |> push_navigate(to: aludel_path("suites/#{suite.id}"))}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> assign(
               :test_cases,
               merge_test_cases_from_params(
                 suite_params,
                 socket.assigns.test_cases,
                 socket.assigns.selected_prompt
               )
             )}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp validate_test_cases(params) do
    test_cases = params["test_cases"] || %{}

    test_cases
    |> Enum.reduce_while(:ok, fn {_id, test_case_params}, _acc ->
      case parse_test_case_assertions(test_case_params) do
        {:ok, _assertions} -> {:cont, :ok}
        {:error, _message} = error -> {:halt, error}
      end
    end)
  end

  defp parse_test_case_assertions(%{"assertions_json" => assertions_json}) do
    AssertionParser.parse(:json, %{"assertions_json" => assertions_json})
  end

  defp parse_test_case_assertions(test_case_params) do
    AssertionParser.parse(:visual, test_case_params)
  end

  defp create_suite_with_test_cases(params) do
    test_cases_params = extract_test_cases(params)

    case Evals.create_suite(Map.drop(params, ["test_cases"])) do
      {:ok, suite} ->
        create_test_cases_for_suite(suite, test_cases_params)
        {:ok, suite}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp extract_test_cases(params) do
    test_cases = params["test_cases"] || %{}

    test_cases
    |> Enum.map(fn {_id, test_case_params} ->
      variable_values = Map.get(test_case_params, "variable_values", %{})

      assertions =
        case parse_test_case_assertions(test_case_params) do
          {:ok, assertions} -> assertions
          {:error, _message} -> []
        end

      %{
        variable_values: variable_values,
        assertions: assertions
      }
    end)
    |> Enum.reject(fn tc -> tc.variable_values == %{} end)
  end

  defp create_test_cases_for_suite(suite, test_cases_params) do
    Enum.each(test_cases_params, fn tc_params ->
      Evals.create_test_case(Map.put(tc_params, :suite_id, suite.id))
    end)
  end

  defp update_suite_with_test_cases(suite, params) do
    test_cases_params = extract_test_cases(params)

    case Evals.update_suite(suite, Map.drop(params, ["test_cases"])) do
      {:ok, suite} ->
        # Delete existing test cases and create new ones
        Enum.each(suite.test_cases, fn tc -> Evals.delete_test_case(tc) end)
        create_test_cases_for_suite(suite, test_cases_params)
        {:ok, suite}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp merge_test_case_assertions(test_case_params) do
    case parse_test_case_assertions(test_case_params) do
      {:ok, assertions} -> assertions
      {:error, _message} -> []
    end
  end

  defp extract_variables(template) do
    ~r/\{\{([^}]+)\}\}/
    |> Regex.scan(template)
    |> Enum.map(fn [_, var] -> String.trim(var) end)
    |> Enum.uniq()
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp find_selected_prompt(_prompts, prompt_id) when prompt_id in [nil, ""], do: nil
  defp find_selected_prompt(prompts, prompt_id), do: Enum.find(prompts, &(&1.id == prompt_id))

  defp sync_test_case_variables(test_cases, selected_prompt) do
    variables = prompt_variables(selected_prompt)

    Enum.map(test_cases, fn tc ->
      variable_values =
        variables
        |> Enum.map(fn var -> {var, Map.get(tc[:variable_values] || %{}, var, "")} end)
        |> Map.new()

      Map.put(tc, :variable_values, variable_values)
    end)
  end

  defp merge_test_cases_from_params(
         %{"test_cases" => test_cases_params},
         _current_test_cases,
         selected_prompt
       )
       when is_map(test_cases_params) and map_size(test_cases_params) > 0 do
    variables = prompt_variables(selected_prompt)

    Enum.map(test_cases_params, fn {id, test_case_params} ->
      variable_values =
        variables
        |> Enum.map(fn var ->
          {var, get_in(test_case_params, ["variable_values", var]) || ""}
        end)
        |> Map.new()

      %{
        id: id,
        variable_values: variable_values,
        assertions: merge_test_case_assertions(test_case_params)
      }
    end)
  end

  defp merge_test_cases_from_params(
         %{"test_cases" => _test_cases_params},
         current_test_cases,
         selected_prompt
       ) do
    sync_test_case_variables(current_test_cases, selected_prompt)
  end

  defp merge_test_cases_from_params(_suite_params, current_test_cases, selected_prompt) do
    sync_test_case_variables(current_test_cases, selected_prompt)
  end

  defp prompt_variables(%{versions: [%{template: template} | _]}), do: extract_variables(template)
  defp prompt_variables(_selected_prompt), do: []
end
