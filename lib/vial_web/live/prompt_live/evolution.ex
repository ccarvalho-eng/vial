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

  defp pass_rate_color(rate) when rate >= 90, do: "bg-green-100 text-green-800"
  defp pass_rate_color(rate) when rate >= 70, do: "bg-yellow-100 text-yellow-800"
  defp pass_rate_color(_rate), do: "bg-red-100 text-red-800"
end
