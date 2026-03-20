defmodule VialWeb.RunLive.Show do
  @moduledoc """
  LiveView for displaying run details and streaming results.

  Subscribes to PubSub for real-time updates as provider results
  stream in. Displays run configuration, variable values, and
  side-by-side provider results with metrics.
  """

  use VialWeb, :live_view

  alias Vial.Runs

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    run = Runs.get_run!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vial.PubSub, "run:#{id}")
    end

    title = if run.name, do: run.name, else: "Run"

    socket =
      socket
      |> assign(:page_title, title)
      |> assign(:run, run)
      |> assign(:run_results, run.run_results)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:run_result_update, _result_id, _status, _output},
        socket
      ) do
    run = Runs.get_run!(socket.assigns.run.id)
    {:noreply, assign(socket, run_results: run.run_results)}
  end
end
