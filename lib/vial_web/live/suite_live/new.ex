defmodule VialWeb.SuiteLive.New do
  @moduledoc """
  LiveView for creating a new evaluation suite.
  """

  use VialWeb, :live_view

  alias Vial.Evals
  alias Vial.Evals.Suite
  alias Vial.Hooks
  alias Vial.Prompts

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
  def handle_event("prompt_selected", %{"suite" => %{"prompt_id" => prompt_id}}, socket) do
    selected_prompt =
      if prompt_id != "" do
        Enum.find(socket.assigns.prompts, fn p -> p.id == prompt_id end)
      else
        nil
      end

    {:noreply, assign(socket, :selected_prompt, selected_prompt)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_test_case", _params, socket) do
    test_cases = socket.assigns.test_cases ++ [%{id: generate_id()}]
    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_test_case", %{"id" => id}, socket) do
    test_cases = Enum.reject(socket.assigns.test_cases, fn tc -> tc.id == id end)
    {:noreply, assign(socket, :test_cases, test_cases)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"suite" => suite_params}, socket) do
    save_suite(socket, socket.assigns.live_action, suite_params)
  end

  defp apply_action(socket, :new, _params) do
    repo = Hooks.get_repo(socket)
    changeset = Evals.change_suite(%Suite{})
    prompts = Prompts.list_prompts_with_versions(repo)

    socket
    |> assign(:page_title, "New Suite")
    |> assign(:suite, %Suite{})
    |> assign(:form, to_form(changeset))
    |> assign(:prompts, prompts)
    |> assign(:selected_prompt, nil)
    |> assign(:test_cases, [%{id: generate_id()}])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    repo = Hooks.get_repo(socket)
    suite = Evals.get_suite_with_test_cases_and_prompt!(repo, id)
    changeset = Evals.change_suite(suite)
    prompts = Prompts.list_prompts_with_versions(repo)

    test_cases =
      if suite.test_cases == [] do
        [%{id: generate_id()}]
      else
        Enum.map(suite.test_cases, fn tc ->
          Map.put(tc, :id, tc.id || generate_id())
        end)
      end

    socket
    |> assign(:page_title, "Edit Suite")
    |> assign(:suite, suite)
    |> assign(:form, to_form(changeset))
    |> assign(:prompts, prompts)
    |> assign(:selected_prompt, suite.prompt)
    |> assign(:test_cases, test_cases)
  end

  defp save_suite(socket, :new, suite_params) do
    repo = Hooks.get_repo(socket)
    test_case_params = parse_test_cases(suite_params, socket.assigns.selected_prompt)

    # Validate test cases
    test_errors = validate_test_cases(test_case_params)

    if test_errors == [] do
      create_suite_with_test_cases(socket, repo, suite_params, test_case_params)
    else
      errors = Enum.join(test_errors, ", ")

      {:noreply,
       socket
       |> put_flash(:error, errors)
       |> assign(:test_case_errors, test_errors)}
    end
  end

  defp save_suite(socket, :edit, suite_params) do
    repo = Hooks.get_repo(socket)
    suite = socket.assigns.suite
    test_case_params = parse_test_cases(suite_params, socket.assigns.selected_prompt)

    # Validate test cases
    test_errors = validate_test_cases(test_case_params)

    if test_errors == [] do
      update_suite_with_test_cases(socket, repo, suite, suite_params, test_case_params)
    else
      errors = Enum.join(test_errors, ", ")

      {:noreply,
       socket
       |> put_flash(:error, errors)
       |> assign(:test_case_errors, test_errors)}
    end
  end

  defp create_suite_with_test_cases(socket, repo, suite_params, test_case_params) do
    params = prepare_suite_params(suite_params)

    case Evals.create_suite(repo, Map.drop(params, ["test_cases"])) do
      {:ok, suite} ->
        # Create test cases
        create_test_cases_for_suite(repo, suite, test_case_params)

        {:noreply,
         socket
         |> put_flash(:info, "Suite created successfully")
         |> push_navigate(to: vial_path(socket, "/suites/#{suite.id}"))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp update_suite_with_test_cases(socket, repo, suite, suite_params, test_case_params) do
    params = prepare_suite_params(suite_params)

    case Evals.update_suite(repo, suite, Map.drop(params, ["test_cases"])) do
      {:ok, updated_suite} ->
        # Delete existing test cases and create new ones
        Enum.each(suite.test_cases, fn tc -> Evals.delete_test_case(repo, tc) end)

        create_test_cases_for_suite(repo, updated_suite, test_case_params)

        {:noreply,
         socket
         |> put_flash(:info, "Suite updated successfully")
         |> push_navigate(to: vial_path(socket, "/suites/#{updated_suite.id}"))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp create_test_cases_for_suite(repo, suite, test_case_params) do
    Enum.each(test_case_params, fn tc_params ->
      Evals.create_test_case(repo, Map.put(tc_params, :suite_id, suite.id))
    end)
  end

  defp prepare_suite_params(params) do
    # Convert string tags to array
    tags = params["tags"] || ""

    tags_list =
      tags
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "tags", tags_list)
  end

  defp parse_test_cases(suite_params, selected_prompt) do
    test_cases_map = Map.get(suite_params, "test_cases", %{})

    # Get variable names from selected prompt
    variable_names =
      if selected_prompt && selected_prompt.versions != [] do
        List.first(selected_prompt.versions).variables
      else
        []
      end

    test_cases_map
    |> Map.values()
    |> Enum.filter(fn tc -> tc["name"] && tc["name"] != "" end)
    |> Enum.map(fn tc ->
      # Build variable values map from the test case form data
      variable_values =
        Map.new(variable_names, fn var_name ->
          {var_name, Map.get(tc, var_name, "")}
        end)

      # Parse assertions from the form
      assertions =
        tc
        |> Map.get("assertions", %{})
        |> Map.values()
        |> Enum.filter(fn a -> a["type"] && a["type"] != "" && a["value"] && a["value"] != "" end)

      %{
        name: tc["name"],
        description: tc["description"] || "",
        variable_values: variable_values,
        assertions: assertions
      }
    end)
  end

  defp validate_test_cases(test_cases) do
    if test_cases == [] do
      ["At least one test case is required"]
    else
      Enum.flat_map(test_cases, fn tc ->
        errors = []

        errors =
          if tc.name == "" || tc.name == nil do
            ["Test case name is required" | errors]
          else
            errors
          end

        errors =
          if tc.assertions == [] do
            ["Each test case must have at least one assertion" | errors]
          else
            errors
          end

        errors
      end)
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
end
