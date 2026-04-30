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
       :test_case_form_params,
       merge_test_case_form_params(suite_params, socket.assigns.test_cases, selected_prompt)
     )
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

    {:noreply,
     socket
     |> assign(:test_cases, test_cases)
     |> put_test_case_form_params(new_test_case)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_test_case", %{"id" => id}, socket) do
    test_cases = Enum.reject(socket.assigns.test_cases, fn tc -> tc.id == id end)

    {:noreply,
     socket
     |> assign(:test_cases, test_cases)
     |> assign(:test_case_form_params, Map.delete(socket.assigns.test_case_form_params, id))
     |> assign(:assertion_edit_mode, Map.delete(socket.assigns.assertion_edit_mode, id))}
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

    {:noreply, sync_test_case_form_params(socket, test_cases, id)}
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

    {:noreply, sync_test_case_form_params(socket, test_cases, id)}
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
    |> assign(:test_case_form_params, %{})
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
    |> assign(:test_case_form_params, build_test_case_form_params_map(test_cases))
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
    case preview_test_case_assertions(test_case_params) do
      {:ok, assertions} -> assertions
      {:error, _message} -> []
    end
  end

  defp preview_test_case_assertions(%{"assertions_json" => assertions_json}) do
    AssertionParser.parse(:json, %{"assertions_json" => assertions_json})
  end

  defp preview_test_case_assertions(test_case_params) do
    AssertionParser.preview_visual(test_case_params)
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

  defp merge_test_case_form_params(
         %{"test_cases" => test_cases_params},
         _current_test_cases,
         selected_prompt
       )
       when is_map(test_cases_params) and map_size(test_cases_params) > 0 do
    variables = prompt_variables(selected_prompt)

    Map.new(test_cases_params, fn {id, test_case_params} ->
      variable_values =
        variables
        |> Enum.map(fn var ->
          {var, get_in(test_case_params, ["variable_values", var]) || ""}
        end)
        |> Map.new()

      assertion_params =
        test_case_params
        |> Map.get("assertions", %{})
        |> normalize_form_assertion_params()

      assertions = merge_test_case_assertions(test_case_params)

      form_params =
        %{"variable_values" => variable_values}
        |> Map.merge(AssertionParser.build_form_params(assertions))
        |> Map.put("assertions", assertion_params)
        |> maybe_put_assertions_json_param(test_case_params)

      {id, form_params}
    end)
  end

  defp merge_test_case_form_params(
         %{"test_cases" => _test_cases_params},
         current_test_cases,
         selected_prompt
       ) do
    current_test_cases
    |> sync_test_case_variables(selected_prompt)
    |> build_test_case_form_params_map()
  end

  defp merge_test_case_form_params(_suite_params, current_test_cases, selected_prompt) do
    current_test_cases
    |> sync_test_case_variables(selected_prompt)
    |> build_test_case_form_params_map()
  end

  defp build_test_case_form_params_map(test_cases) do
    Map.new(test_cases, fn test_case ->
      {test_case.id, build_test_case_form_params(test_case)}
    end)
  end

  defp build_test_case_form_params(test_case) do
    %{
      "variable_values" => test_case[:variable_values] || %{}
    }
    |> Map.merge(AssertionParser.build_form_params(test_case[:assertions] || []))
  end

  defp put_test_case_form_params(socket, test_case) do
    assign(
      socket,
      :test_case_form_params,
      Map.put(
        socket.assigns.test_case_form_params,
        test_case.id,
        build_test_case_form_params(test_case)
      )
    )
  end

  defp sync_test_case_form_params(socket, test_cases, id) do
    updated_test_case = Enum.find(test_cases, &(&1.id == id))

    socket
    |> assign(:test_cases, test_cases)
    |> put_test_case_form_params(updated_test_case)
  end

  defp maybe_put_assertions_json_param(form_params, %{"assertions_json" => assertions_json}) do
    Map.put(form_params, "assertions_json", assertions_json || "")
  end

  defp maybe_put_assertions_json_param(form_params, _test_case_params), do: form_params

  defp normalize_form_assertion_params(params) when is_map(params), do: params
  defp normalize_form_assertion_params(params) when is_list(params), do: Map.new(params)
  defp normalize_form_assertion_params(_params), do: %{}

  defp current_assertion_type(test_case_id, idx, form_params, assertion) do
    assertion_form_value(test_case_id, idx, "type", form_params) || assertion["type"] ||
      "contains"
  end

  defp assertion_text_value(test_case_id, idx, field_name, assertion_key, form_params, assertion) do
    case assertion_form_value(test_case_id, idx, field_name, form_params) ||
           assertion[assertion_key] do
      nil -> ""
      value -> display_value(value)
    end
  end

  defp assertion_expected_json_value_for_json_field(test_case_id, idx, form_params, assertion) do
    case assertion_form_value(test_case_id, idx, "expected_json_value", form_params) do
      nil ->
        Jason.encode!(Map.get(assertion, "expected", ""))

      value ->
        value
    end
  end

  defp assertion_expected_json_value(test_case_id, idx, form_params, assertion) do
    case assertion_form_value(test_case_id, idx, "expected_json", form_params) do
      nil ->
        if is_map(assertion["expected"]) or is_list(assertion["expected"]) do
          Jason.encode!(assertion["expected"], pretty: true)
        else
          ""
        end

      value ->
        value
    end
  end

  defp assertion_threshold_value(test_case_id, idx, form_params, assertion) do
    case assertion_form_value(test_case_id, idx, "threshold", form_params) do
      nil ->
        if is_number(assertion["threshold"]), do: to_string(assertion["threshold"]), else: ""

      value ->
        value
    end
  end

  defp assertion_form_value(test_case_id, idx, field_name, form_params) do
    form_params
    |> Map.get(test_case_id, %{})
    |> Map.get("assertions", %{})
    |> normalize_form_assertion_params()
    |> Map.get("assertion_#{field_name}_#{idx}")
  end

  defp test_case_assertions_json_value(test_case, form_params) do
    case Map.get(form_params, test_case.id, %{}) do
      %{"assertions_json" => assertions_json} ->
        assertions_json

      _other ->
        if test_case[:assertions], do: Jason.encode!(test_case.assertions, pretty: true), else: ""
    end
  end

  defp display_value(nil), do: "null"
  defp display_value(value) when is_binary(value), do: value

  defp display_value(value) when is_integer(value) or is_float(value) or is_boolean(value),
    do: inspect(value)

  defp display_value(value) when is_map(value) or is_list(value), do: Jason.encode!(value)
  defp display_value(value), do: to_string(value)

  defp prompt_variables(%{versions: [%{template: template} | _]}), do: extract_variables(template)
  defp prompt_variables(_selected_prompt), do: []
end
