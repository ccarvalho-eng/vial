defmodule Aludel.Web.ProviderLive.New do
  @moduledoc """
  LiveView for creating and editing AI providers.
  """

  use Aludel.Web, :live_view

  alias Aludel.Providers
  alias Aludel.Providers.Provider

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"provider" => provider_params}, socket) do
    changeset =
      socket.assigns.provider
      |> Providers.change_provider(provider_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:config_json, Map.get(provider_params, "config", ""))}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.live_action, provider_params)
  end

  defp apply_action(socket, :new, _params) do
    changeset = Providers.change_provider(%Provider{})

    socket
    |> assign(:page_title, "New Provider")
    |> assign(:provider, %Provider{})
    |> assign(:config_json, "")
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = Providers.get_provider!(id)
    changeset = Providers.change_provider(provider)

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:config_json, encode_config(provider.config))
    |> assign(:form, to_form(changeset))
  end

  defp save_provider(socket, :new, provider_params) do
    config_json = Map.get(provider_params, "config", "")

    # Parse config JSON if provided
    provider_params = parse_config(provider_params)

    case Providers.create_provider(provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider created successfully")
         |> push_navigate(to: aludel_path("providers"))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:config_json, config_json)}
    end
  end

  defp save_provider(socket, :edit, provider_params) do
    config_json = Map.get(provider_params, "config", "")

    # Parse config JSON if provided
    provider_params = parse_config(provider_params)

    case Providers.update_provider(socket.assigns.provider, provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider updated successfully")
         |> push_navigate(to: aludel_path("providers"))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:config_json, config_json)}
    end
  end

  defp parse_config(params) do
    case params["config"] do
      nil ->
        params

      "" ->
        Map.put(params, "config", %{})

      config_str ->
        case Jason.decode(config_str) do
          {:ok, config} -> Map.put(params, "config", config)
          {:error, _} -> params
        end
    end
  end

  defp encode_config(nil), do: ""
  defp encode_config(config) when map_size(config) == 0, do: ""
  defp encode_config(config), do: Jason.encode!(config, pretty: true)
end
