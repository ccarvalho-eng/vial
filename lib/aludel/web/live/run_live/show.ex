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
    run = Runs.get_run!(updated_result.run_id)

    {:noreply, assign(socket, run: run, run_results: run.run_results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:run_update, _status}, socket) do
    run = Runs.get_run!(socket.assigns.run.id)

    {:noreply, assign(socket, run: run, run_results: run.run_results)}
  end

  defp format_token_usage(result) do
    [format_optional_integer(result.input_tokens), format_optional_integer(result.output_tokens)]
    |> Enum.join(" / ")
  end

  defp format_optional_integer(nil), do: "N/A"
  defp format_optional_integer(value), do: Integer.to_string(value)

  defp format_latency(nil), do: "N/A"
  defp format_latency(value), do: "#{value} ms"

  defp format_cost(nil), do: "N/A"
  defp format_cost(value), do: "$#{:erlang.float_to_binary(value, decimals: 4)}"

  defp show_result_metadata?(%{metadata: metadata}) when is_map(metadata),
    do: map_size(metadata) > 0

  defp show_result_metadata?(_result), do: false

  defp format_result_metadata(metadata), do: Jason.encode!(metadata, pretty: true)
end
