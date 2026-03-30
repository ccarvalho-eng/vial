defmodule Aludel.Web.DashboardLive do
  @moduledoc """
  LiveView for displaying the dashboard with recent runs, cost
  aggregation, and pass rate statistics.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.Runs
  alias Aludel.Stats

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:show_cost_breakdown, false)
      |> assign(:cost_view, :provider)
      |> assign(:show_latency_breakdown, false)
      |> assign(:show_activity_chart, false)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    recent_activity = Stats.list_recent_activity(10)
    pass_rates = Evals.pass_rates_by_prompt() |> sort_by_pass_rate()

    # Calculate key metrics
    total_runs = Stats.total_runs()
    {total_passed, total_failed} = Stats.test_totals()
    success_rate = Stats.success_rate(total_passed, total_failed)
    avg_latency = Stats.avg_latency()
    latency_percentiles = Stats.latency_percentiles()
    total_cost = Runs.total_cost()
    cost_per_run = Stats.cost_per_run()
    trends = Stats.comparison_stats(7)

    # Breakdown stats
    cost_by_provider = Stats.cost_by_provider()
    cost_by_prompt = Stats.cost_by_prompt()
    latency_by_provider = Stats.latency_by_provider()
    daily_activity = Stats.daily_activity(30)

    # Get last run time
    last_run_at = if recent_activity != [], do: List.first(recent_activity).inserted_at, else: nil

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:recent_activity, recent_activity)
      |> assign(:pass_rates, pass_rates)
      |> assign(:total_runs, total_runs)
      |> assign(:total_passed, total_passed)
      |> assign(:total_failed, total_failed)
      |> assign(:success_rate, success_rate)
      |> assign(:avg_latency, avg_latency)
      |> assign(:latency_p50, latency_percentiles.p50)
      |> assign(:latency_p95, latency_percentiles.p95)
      |> assign(:total_cost, total_cost)
      |> assign(:cost_per_run, cost_per_run)
      |> assign(:trends, trends)
      |> assign(:cost_by_provider, cost_by_provider)
      |> assign(:cost_by_prompt, cost_by_prompt)
      |> assign(:latency_by_provider, latency_by_provider)
      |> assign(:daily_activity, daily_activity)
      |> assign(:last_run_at, last_run_at)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_cost_breakdown", _params, socket) do
    new_value = !socket.assigns.show_cost_breakdown

    socket =
      socket
      |> assign(:show_cost_breakdown, new_value)
      |> assign(:show_latency_breakdown, false)
      |> assign(:show_activity_chart, false)

    {:noreply, socket}
  end

  def handle_event("toggle_latency_breakdown", _params, socket) do
    new_value = !socket.assigns.show_latency_breakdown

    socket =
      socket
      |> assign(:show_cost_breakdown, false)
      |> assign(:show_latency_breakdown, new_value)
      |> assign(:show_activity_chart, false)

    {:noreply, socket}
  end

  def handle_event("toggle_activity_chart", _params, socket) do
    new_value = !socket.assigns.show_activity_chart

    socket =
      socket
      |> assign(:show_cost_breakdown, false)
      |> assign(:show_latency_breakdown, false)
      |> assign(:show_activity_chart, new_value)

    {:noreply, socket}
  end

  def handle_event("toggle_cost_view", _params, socket) do
    new_view = if socket.assigns.cost_view == :provider, do: :prompt, else: :provider
    {:noreply, assign(socket, :cost_view, new_view)}
  end

  defp sort_by_pass_rate(pass_rates) do
    Enum.sort_by(pass_rates, fn rate ->
      total = (rate.total_passed || 0) + (rate.total_failed || 0)

      if total > 0 do
        -(rate.total_passed || 0) / total
      else
        0
      end
    end)
  end
end
