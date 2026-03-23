defmodule VialWeb.SuiteLive.Index do
  @moduledoc """
  LiveView for listing evaluation suites.

  Displays all suites with their associated prompt names.
  """

  use VialWeb, :live_view

  alias Vial.Evals

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    suites = Evals.list_suites_with_prompt()

    socket =
      socket
      |> assign(:page_title, "Suites")
      |> assign(:suites, suites)
      |> assign(:running_suite_id, nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    suite = Evals.get_suite!(id)
    {:ok, _} = Evals.delete_suite(suite)

    {:noreply,
     socket
     |> assign(:suites, Evals.list_suites_with_prompt())
     |> put_flash(:info, "Suite deleted successfully")}
  end

  @impl Phoenix.LiveView
  def handle_event("run_suite", %{"id" => id}, socket) do
    suite = Evals.get_suite_with_test_cases_and_prompt!(id)
    prompt = Vial.Prompts.get_prompt_with_versions!(suite.prompt_id)
    providers = Vial.Providers.list_providers()

    case {prompt.versions, providers} do
      {[], _} ->
        {:noreply, put_flash(socket, :error, "No prompt versions available")}

      {_, []} ->
        {:noreply, put_flash(socket, :error, "No providers configured")}

      {[version | _], [provider | _]} ->
        # Start async execution
        pid = self()
        suite_id = suite.id

        Task.Supervisor.start_child(Vial.TaskSupervisor, fn ->
          suite = Evals.get_suite_with_test_cases_and_prompt!(suite_id)
          result = Evals.execute_suite(suite, version, provider)
          send(pid, {:suite_run_completed, suite_id, result})
        end)

        {:noreply, assign(socket, :running_suite_id, suite.id)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_run_completed, suite_id, {:ok, _suite_run}}, socket) do
    suite = Evals.get_suite_with_prompt!(suite_id)

    {:noreply,
     socket
     |> assign(:running_suite_id, nil)
     |> put_flash(:info, "Suite '#{suite.name}' executed successfully")
     |> push_navigate(to: ~p"/suites/#{suite_id}")}
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_run_completed, _suite_id, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(:running_suite_id, nil)
     |> put_flash(:error, "Failed to execute suite")}
  end
end
