defmodule VialWeb.ProviderLive.Index do
  @moduledoc """
  LiveView for listing and managing AI providers.
  """

  use VialWeb, :live_view

  alias Vial.Hooks
  alias Vial.Providers

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    repo = Hooks.get_repo(socket)
    providers = Providers.list_providers(repo)

    socket =
      socket
      |> assign(:page_title, "Providers")
      |> assign(:providers, providers)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    repo = Hooks.get_repo(socket)
    provider = Providers.get_provider!(repo, id)
    {:ok, _} = Providers.delete_provider(repo, provider)

    {:noreply,
     socket
     |> assign(:providers, Providers.list_providers(repo))
     |> put_flash(:info, "Provider deleted successfully")}
  end
end
