defmodule Aludel.Web.PromptLive.Show do
  @moduledoc """
  LiveView for displaying a prompt and all its versions.
  """

  use Aludel.Web, :live_view

  alias Aludel.Prompts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    prompt = Prompts.get_prompt_with_versions!(id)
    latest_version = List.first(prompt.versions)

    {:noreply,
     socket
     |> assign(:page_title, prompt.name)
     |> assign(:prompt, prompt)
     |> assign(:selected_version_id, latest_version && latest_version.id)}
  end

  @impl Phoenix.LiveView
  def handle_event("select_version", %{"version-id" => version_id}, socket) do
    {:noreply, assign(socket, :selected_version_id, version_id)}
  end
end
