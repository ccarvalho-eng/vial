defmodule Vial.Web.PromptLive.Show do
  @moduledoc """
  LiveView for displaying a prompt and all its versions.
  """

  use Vial.Web, :live_view

  alias Vial.Prompts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    prompt = Prompts.get_prompt_with_versions!(id)

    {:noreply,
     socket
     |> assign(:page_title, prompt.name)
     |> assign(:prompt, prompt)}
  end
end
