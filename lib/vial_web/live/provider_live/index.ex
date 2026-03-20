defmodule VialWeb.ProviderLive.Index do
  @moduledoc """
  LiveView for listing and managing AI providers.
  """

  use VialWeb, :live_view

  alias Vial.Providers

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    providers = Providers.list_providers()

    socket =
      socket
      |> assign(:page_title, "Providers")
      |> assign(:providers, providers)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Providers.get_provider!(id)
    {:ok, _} = Providers.delete_provider(provider)

    {:noreply,
     socket
     |> assign(:providers, Providers.list_providers())
     |> put_flash(:info, "Provider deleted successfully")}
  end
end
