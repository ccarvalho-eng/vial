defmodule Aludel.Web.ProviderLive.Index do
  @moduledoc """
  LiveView for listing and managing AI providers.
  """

  use Aludel.Web, :live_view

  alias Aludel.LLM.Pricing
  alias Aludel.Providers

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
      |> assign(:provider_pricing, resolve_provider_pricing(providers))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Providers.get_provider!(id)
    {:ok, _} = Providers.delete_provider(provider)

    providers = Providers.list_providers()

    {:noreply,
     socket
     |> assign(:providers, providers)
     |> assign(:provider_pricing, resolve_provider_pricing(providers))
     |> put_flash(:info, "Provider deleted successfully")}
  end

  defp resolve_provider_pricing(providers) do
    Map.new(providers, fn provider ->
      pricing = Pricing.get_pricing(provider.provider, provider.model, provider.pricing)
      is_custom = is_map(provider.pricing) and map_size(provider.pricing) > 0
      {provider.id, %{pricing: pricing, custom: is_custom}}
    end)
  end
end
