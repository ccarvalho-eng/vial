defmodule VialWeb.DashboardLive do
  @moduledoc """
  LiveView for displaying the dashboard with recent runs, cost
  aggregation, and pass rate statistics.
  """

  use VialWeb, :live_view

  alias Vial.Evals
  alias Vial.Runs
  alias Vial.Stats

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
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
    total_cost = Runs.total_cost()

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
      |> assign(:total_cost, total_cost)
      |> assign(:last_run_at, last_run_at)

    {:noreply, socket}
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
