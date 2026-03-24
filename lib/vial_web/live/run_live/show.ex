defmodule VialWeb.RunLive.Show do
  @moduledoc """
  LiveView for displaying run details and streaming results.

  Subscribes to PubSub for real-time updates as provider results
  stream in. Displays run configuration, variable values, and
  side-by-side provider results with metrics.
  """

  use VialWeb, :live_view

  alias Vial.Hooks
  alias Vial.Runs

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    repo = Hooks.get_repo(socket)
    run = Runs.get_run!(repo, id)

    if connected?(socket) do
      # Subscribe to run-specific updates. Topic format: "run:#{run_id}"
      # NOTE: If multi-tenancy is added in the future, scope topics by org/user:
      # "run:#{org_id}:#{id}" to prevent data leaks between tenants
      pubsub = socket.endpoint.config(:pubsub_server)
      Phoenix.PubSub.subscribe(pubsub, "run:#{id}")
    end

    title = if run.name, do: run.name, else: "Run"

    socket =
      socket
      |> assign(:page_title, title)
      |> assign(:run, run)
      |> assign(:run_results, run.run_results)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:run_result_update, _result_id, _status, _output},
        socket
      ) do
    repo = Hooks.get_repo(socket)
    run = Runs.get_run!(repo, socket.assigns.run.id)
    {:noreply, assign(socket, run_results: run.run_results)}
  end
end
