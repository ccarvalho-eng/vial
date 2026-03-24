defmodule VialWeb.PromptLive.Evolution do
  @moduledoc """
  LiveView for displaying prompt evolution metrics and performance
  trends with interactive charting.
  """

  use VialWeb, :live_view

  alias Vial.Hooks
  alias Vial.Prompts
  alias Vial.Prompts.Evolution

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, view_mode: :overall)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    repo = Hooks.get_repo(socket)

    prompt = Prompts.get_prompt!(repo, id)
    metrics = Prompts.get_evolution_metrics(repo, id)
    chart_data = Evolution.prepare_chart_data(metrics)

    {:noreply,
     socket
     |> assign(:page_title, "#{prompt.name} - Evolution")
     |> assign(:prompt, prompt)
     |> assign(:metrics, metrics)
     |> assign(:chart_data, chart_data)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode =
      case socket.assigns.view_mode do
        :overall -> :by_provider
        :by_provider -> :overall
      end

    {:noreply,
     socket
     |> assign(view_mode: new_mode)
     |> push_event("update-chart", %{
       chart_data: socket.assigns.chart_data,
       view_mode: new_mode
     })}
  end

  @impl Phoenix.LiveView
  def handle_event("chart-mounted", _params, socket) do
    {:noreply,
     push_event(socket, "update-chart", %{
       chart_data: socket.assigns.chart_data,
       view_mode: socket.assigns.view_mode
     })}
  end
end
