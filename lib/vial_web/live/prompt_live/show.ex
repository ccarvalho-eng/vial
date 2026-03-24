defmodule VialWeb.PromptLive.Show do
  @moduledoc """
  LiveView for displaying a prompt and all its versions.
  """

  use VialWeb, :live_view

  alias Vial.Prompts
  alias Vial.Hooks

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    repo = Hooks.get_repo(socket)
    prompt = Prompts.get_prompt_with_versions!(repo, id)

    {:noreply,
     socket
     |> assign(:page_title, prompt.name)
     |> assign(:prompt, prompt)}
  end
end
