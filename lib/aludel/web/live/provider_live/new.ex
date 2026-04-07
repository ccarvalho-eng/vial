defmodule Aludel.Web.ProviderLive.New do
  @moduledoc """
  LiveView for creating and editing AI providers.
  """

  use Aludel.Web, :live_view

  alias Aludel.Providers
  alias Aludel.Providers.Provider

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    model_groups = %{active: [], deprecated: []}

    {:ok,
     assign(socket,
       model_groups: model_groups,
       model_options: model_options(model_groups)
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"provider" => provider_params}, socket) do
    provider_type = provider_params["provider"]
    model_groups = Providers.fetch_model_groups(provider_type)

    changeset =
      socket.assigns.provider
      |> Providers.change_provider(provider_params)
      |> ensure_model_selection(model_groups)
      |> validate_model_selection()
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:model_groups, model_groups)
     |> assign(:model_options, model_options(model_groups))
     |> assign(:form, to_form(changeset))
     |> assign(:config_json, Map.get(provider_params, "config", ""))}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.live_action, provider_params)
  end

  defp apply_action(socket, :new, _params) do
    changeset = Providers.change_provider(%Provider{})
    model_groups = %{active: [], deprecated: []}

    socket
    |> assign(:page_title, "New Provider")
    |> assign(:provider, %Provider{})
    |> assign(:model_groups, model_groups)
    |> assign(:model_options, model_options(model_groups))
    |> assign(:config_json, "")
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = Providers.get_provider!(id)
    model_groups = Providers.fetch_model_groups(provider.provider)

    changeset =
      provider
      |> Providers.change_provider()
      |> ensure_model_selection(model_groups)
      |> validate_model_selection()

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:model_groups, model_groups)
    |> assign(:model_options, model_options(model_groups))
    |> assign(:config_json, encode_config(provider.config))
    |> assign(:form, to_form(changeset))
  end

  defp save_provider(socket, :new, provider_params) do
    config_json = Map.get(provider_params, "config", "")

    # Parse config JSON if provided
    provider_params = provider_params |> normalize_model_params() |> parse_config()

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
    provider_params = provider_params |> normalize_model_params() |> parse_config()

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

  defp normalize_model_params(params) do
    case params["model_selection"] do
      "custom" -> Map.put(params, "model", params["model_custom"])
      value when is_binary(value) and value != "" -> Map.put(params, "model", value)
      _ -> params
    end
  end

  defp ensure_model_selection(changeset, model_groups) do
    selection = Ecto.Changeset.get_field(changeset, :model_selection)
    model = Ecto.Changeset.get_field(changeset, :model)
    custom_model = Ecto.Changeset.get_field(changeset, :model_custom)

    cond do
      selection == "custom" ->
        changeset
        |> Ecto.Changeset.put_change(:model_custom, custom_model || model)
        |> Ecto.Changeset.put_change(:model, custom_model || model)

      is_binary(selection) and selection != "" ->
        changeset

      model_in_groups?(model_groups, model) ->
        changeset
        |> Ecto.Changeset.put_change(:model_selection, model)
        |> Ecto.Changeset.delete_change(:model_custom)

      true ->
        changeset
    end
  end

  defp model_in_groups?(%{active: active, deprecated: deprecated}, model) do
    Enum.any?(active ++ deprecated, &(&1.id == model))
  end

  defp model_options(%{active: active, deprecated: deprecated}) do
    [
      {"Active models", Enum.map(active, &{&1.name, &1.id})},
      {"Deprecated models", Enum.map(deprecated, &{&1.name, &1.id})},
      {"Custom model", [{"Custom", "custom"}]}
    ]
  end

  defp validate_model_selection(changeset) do
    case Ecto.Changeset.get_field(changeset, :model_selection) do
      nil -> Ecto.Changeset.add_error(changeset, :model_selection, "can't be blank")
      "" -> Ecto.Changeset.add_error(changeset, :model_selection, "can't be blank")
      "custom" -> Ecto.Changeset.validate_required(changeset, [:model_custom])
      _ -> changeset
    end
  end
end
