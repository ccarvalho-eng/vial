defmodule Aludel.Web.ProviderLive.New do
  @moduledoc """
  LiveView for creating and editing AI providers.
  """

  use Aludel.Web, :live_view

  alias Aludel.LLM.Pricing
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

    custom_pricing_enabled =
      provider_params["custom_pricing_enabled"] == "true" or
        socket.assigns.custom_pricing_enabled == true

    pricing_input = provider_params["pricing_input"] || socket.assigns.pricing_input || ""
    pricing_output = provider_params["pricing_output"] || socket.assigns.pricing_output || ""

    changeset =
      socket.assigns.provider
      |> Providers.change_provider(
        Map.merge(provider_params, %{
          "custom_pricing_enabled" => custom_pricing_enabled,
          "pricing_input" => pricing_input,
          "pricing_output" => pricing_output
        })
      )
      |> ensure_model_selection(model_groups)
      |> validate_model_selection()
      |> Map.put(:action, :validate)

    model = resolve_model(provider_params, model_groups)
    provider_atom = safe_to_provider_atom(provider_type)
    default_pricing = resolve_default_pricing(provider_atom, model)

    {:noreply,
     socket
     |> assign(:model_groups, model_groups)
     |> assign(:model_options, model_options(model_groups))
     |> assign(:form, to_form(changeset))
     |> assign(:config_json, Map.get(provider_params, "config", ""))
     |> assign(:default_pricing, default_pricing)
     |> assign(:custom_pricing_enabled, custom_pricing_enabled)
     |> assign(:pricing_input, pricing_input)
     |> assign(:pricing_output, pricing_output)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_custom_pricing", _params, socket) do
    enabled = !socket.assigns.custom_pricing_enabled

    changeset =
      socket.assigns.provider
      |> Providers.change_provider(%{
        "custom_pricing_enabled" => enabled,
        "pricing_input" => socket.assigns.pricing_input,
        "pricing_output" => socket.assigns.pricing_output
      })

    {:noreply,
     socket
     |> assign(:custom_pricing_enabled, enabled)
     |> assign(:form, to_form(changeset))}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"provider" => provider_params}, socket) do
    provider_params = apply_pricing_params(provider_params, socket.assigns.custom_pricing_enabled)
    save_provider(socket, socket.assigns.live_action, provider_params)
  end

  defp apply_action(socket, :new, _params) do
    model_groups = %{active: [], deprecated: []}

    changeset =
      Providers.change_provider(%Provider{}, %{
        "custom_pricing_enabled" => false,
        "pricing_input" => "",
        "pricing_output" => ""
      })

    socket
    |> assign(:page_title, "New Provider")
    |> assign(:provider, %Provider{})
    |> assign(:model_groups, model_groups)
    |> assign(:model_options, model_options(model_groups))
    |> assign(:config_json, "")
    |> assign(:form, to_form(changeset))
    |> assign(:default_pricing, nil)
    |> assign(:custom_pricing_enabled, false)
    |> assign(:pricing_input, "")
    |> assign(:pricing_output, "")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = Providers.get_provider!(id)
    model_groups = Providers.fetch_model_groups(provider.provider)

    has_custom_pricing = is_map(provider.pricing) and map_size(provider.pricing) > 0

    {pricing_input, pricing_output} =
      if has_custom_pricing do
        input = provider.pricing["input"] || provider.pricing[:input] || ""
        output = provider.pricing["output"] || provider.pricing[:output] || ""
        {to_string(input), to_string(output)}
      else
        {"", ""}
      end

    changeset =
      provider
      |> Providers.change_provider(%{
        "custom_pricing_enabled" => has_custom_pricing,
        "pricing_input" => pricing_input,
        "pricing_output" => pricing_output
      })
      |> ensure_model_selection(model_groups)
      |> validate_model_selection()

    default_pricing = resolve_default_pricing(provider.provider, provider.model)

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:model_groups, model_groups)
    |> assign(:model_options, model_options(model_groups))
    |> assign(:config_json, encode_config(provider.config))
    |> assign(:form, to_form(changeset))
    |> assign(:default_pricing, default_pricing)
    |> assign(:custom_pricing_enabled, has_custom_pricing)
    |> assign(:pricing_input, pricing_input)
    |> assign(:pricing_output, pricing_output)
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
      custom_selection?(selection) ->
        changeset
        |> Ecto.Changeset.put_change(:model_custom, custom_model)
        |> Ecto.Changeset.put_change(:model, custom_model)

      valid_selection?(model_groups, selection) ->
        changeset
        |> Ecto.Changeset.put_change(:model_selection, selection)
        |> Ecto.Changeset.put_change(:model, selection)
        |> Ecto.Changeset.delete_change(:model_custom)

      invalid_selection?(selection) ->
        changeset
        |> Ecto.Changeset.put_change(:model_selection, nil)
        |> Ecto.Changeset.put_change(:model, nil)
        |> Ecto.Changeset.delete_change(:model_custom)

      model_in_groups?(model_groups, model) ->
        changeset
        |> Ecto.Changeset.put_change(:model_selection, model)
        |> Ecto.Changeset.put_change(:model, model)
        |> Ecto.Changeset.delete_change(:model_custom)

      is_binary(model) and model != "" ->
        changeset
        |> Ecto.Changeset.put_change(:model_selection, "custom")
        |> Ecto.Changeset.put_change(:model_custom, model)

      true ->
        changeset
    end
  end

  defp custom_selection?(selection), do: selection == "custom"

  defp valid_selection?(model_groups, selection) do
    present_value?(selection) and model_in_groups?(model_groups, selection)
  end

  defp invalid_selection?(selection), do: present_value?(selection)

  defp present_value?(value), do: is_binary(value) and value != ""

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

  defp resolve_model(params, model_groups) do
    case params["model_selection"] do
      "custom" -> params["model_custom"]
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
    |> then(fn
      nil -> nil
      model -> if model_in_groups?(model_groups, model), do: model, else: model
    end)
  end

  defp resolve_default_pricing(nil, _model), do: nil
  defp resolve_default_pricing(_provider, nil), do: nil
  defp resolve_default_pricing(_provider, ""), do: nil

  defp resolve_default_pricing(provider, model) do
    Pricing.get_pricing(provider, model)
  end

  defp safe_to_provider_atom(nil), do: nil
  defp safe_to_provider_atom(""), do: nil

  defp safe_to_provider_atom(provider_type) when is_binary(provider_type) do
    String.to_existing_atom(provider_type)
  rescue
    ArgumentError -> nil
  end

  defp apply_pricing_params(params, true) do
    input = parse_pricing_value(params["pricing_input"])
    output = parse_pricing_value(params["pricing_output"])

    if is_number(input) and is_number(output) do
      Map.put(params, "pricing", %{"input" => input, "output" => output})
    else
      params
    end
  end

  defp apply_pricing_params(params, _custom_pricing_disabled) do
    Map.put(params, "pricing", nil)
  end

  defp parse_pricing_value(nil), do: nil
  defp parse_pricing_value(""), do: nil

  defp parse_pricing_value(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> nil
    end
  end
end
