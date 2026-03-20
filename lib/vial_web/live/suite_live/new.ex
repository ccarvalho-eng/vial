defmodule VialWeb.SuiteLive.New do
  @moduledoc """
  LiveView for creating a new evaluation suite.
  """

  use VialWeb, :live_view

  alias Vial.Evals
  alias Vial.Evals.Suite
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
    changeset = Evals.change_suite(%Suite{})
    prompts = Prompts.list_prompts() |> Vial.Repo.preload(:versions)

    socket
    |> assign(:page_title, "New Suite")
    |> assign(:suite, %Suite{})
    |> assign(:form, to_form(changeset))
    |> assign(:prompts, prompts)
    |> assign(:test_cases, [])
    |> assign(:selected_prompt, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    suite = Evals.get_suite!(id) |> Vial.Repo.preload([:prompt, :test_cases])
    changeset = Evals.change_suite(suite)
    prompts = Prompts.list_prompts() |> Vial.Repo.preload(:versions)

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
    |> assign(:test_cases, test_cases)
    |> assign(:selected_prompt, selected_prompt)
  end

  defp save_suite(socket, :new, suite_params) do
    case create_suite_with_test_cases(suite_params) do
      {:ok, suite} ->
        {:noreply,
         socket
         |> put_flash(:info, "Suite created successfully")
         |> push_navigate(to: ~p"/suites/#{suite.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_suite(socket, :edit, suite_params) do
    case update_suite_with_test_cases(socket.assigns.suite, suite_params) do
      {:ok, suite} ->
        {:noreply,
         socket
         |> put_flash(:info, "Suite updated successfully")
         |> push_navigate(to: ~p"/suites/#{suite.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
      variable_values = parse_json_or_empty(test_case_params["variable_values"])
      assertions = parse_assertions(test_case_params["assertions"])

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

  defp parse_json_or_empty(nil), do: %{}
  defp parse_json_or_empty(""), do: %{}

  defp parse_json_or_empty(str) do
    case Jason.decode(str) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  defp parse_assertions(nil), do: []
  defp parse_assertions(""), do: []

  defp parse_assertions(str) do
    case Jason.decode(str) do
      {:ok, assertions} when is_list(assertions) -> assertions
      _ -> []
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
