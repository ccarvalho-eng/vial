defmodule VialWeb.PromptLive.Evolution do
  @moduledoc """
  LiveView for displaying prompt evolution metrics and performance
  trends.
  """

  use VialWeb, :live_view

  alias Vial.Prompts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    prompt = Prompts.get_prompt!(id)
    metrics = Prompts.get_evolution_metrics(id)

    {:noreply,
     socket
     |> assign(:page_title, "#{prompt.name} - Evolution")
     |> assign(:prompt, prompt)
     |> assign(:metrics, metrics)}
  end
end
