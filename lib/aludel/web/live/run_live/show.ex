defmodule Aludel.Web.RunLive.Show do
  @moduledoc """
  LiveView for displaying run details and streaming results.

  Subscribes to PubSub for real-time updates as provider results
  stream in. Displays run configuration, variable values, and
  side-by-side provider results with metrics.
  """

  use Aludel.Web, :live_view

  alias Aludel.PubSub
  alias Aludel.Runs

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    run = Runs.get_run!(id)

    if connected?(socket) do
      # Subscribe to run-specific updates. Topic format: "run:#{run_id}"
      # NOTE: If multi-tenancy is added in the future, scope topics by org/user:
      # "run:#{org_id}:#{id}" to prevent data leaks between tenants
      Phoenix.PubSub.subscribe(PubSub, "run:#{id}")
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
        {:run_result_update, result_id, _status, _output},
        socket
      ) do
    updated_result = Runs.get_run_result!(result_id)
    run_results = merge_run_result(socket.assigns.run_results, updated_result)
    run = %{socket.assigns.run | run_results: run_results}

    {:noreply, assign(socket, run: run, run_results: run_results)}
  end

  defp merge_run_result(run_results, updated_result) do
    {updated_run_results, found_match?} =
      Enum.map_reduce(run_results, false, fn run_result, found_match? ->
        if run_result.id == updated_result.id do
          {updated_result, true}
        else
          {run_result, found_match?}
        end
      end)

    if found_match? do
      updated_run_results
    else
      updated_run_results ++ [updated_result]
    end
  end
end
