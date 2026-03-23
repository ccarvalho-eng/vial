defmodule VialWeb.SuiteLive.Show do
  @moduledoc """
  LiveView for displaying a single evaluation suite.

  Shows suite details, test cases, and allows running the suite
  against a specific prompt version and provider.
  """

  use VialWeb, :live_view

  alias Vial.Evals
  alias Vial.Prompts
  alias Vial.Providers

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
  def handle_event("run_suite", _params, socket) do
    # Use the stored selections instead of params
    version_id = socket.assigns.selected_version_id
    provider_id = socket.assigns.selected_provider_id

    # Start async execution
    pid = self()
    suite_id = socket.assigns.suite.id

    Task.Supervisor.start_child(Vial.TaskSupervisor, fn ->
      version = Prompts.get_prompt_version!(version_id)
      provider = Providers.get_provider!(provider_id)
      suite = Evals.get_suite_with_test_cases!(suite_id)

      result = Evals.execute_suite(suite, version, provider)
      send(pid, {:suite_completed, result})
    end)

    {:noreply, assign(socket, :running, true)}
  end

  @impl Phoenix.LiveView
  def handle_info({:suite_completed, {:ok, suite_run}}, socket) do
    # Suite run comes from execute_suite which returns it after insert,
    # so we need to preload associations here since it's not from a context query
    suite_run = Vial.Repo.preload(suite_run, [:prompt_version, :provider])

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
end
