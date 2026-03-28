defmodule Aludel.Web.Helpers do
  @moduledoc false

  alias Phoenix.VerifiedRoutes

  @doc """
  Construct a path to a dashboard page with optional params.

  Routing is based on a socket and prefix tuple stored in the process dictionary.
  """
  def aludel_path(route, params \\ %{})

  def aludel_path(route, params) when is_list(route) do
    route
    |> Enum.join("/")
    |> aludel_path(params)
  end

  def aludel_path(route, params) do
    # Normalize route to prevent double slashes
    route = String.trim_leading(route, "/")

    params =
      params
      |> Enum.sort()
      |> encode_params()

    case Process.get(:routing) do
      {socket, prefix} ->
        path =
          case prefix do
            "/" -> "/#{route}"
            "" -> "/#{route}"
            _ -> "#{prefix}/#{route}"
          end

        VerifiedRoutes.unverified_path(socket, socket.router, path, params)

      :nowhere ->
        "/"

      nil ->
        raise RuntimeError, "nothing stored in the :routing key"
    end
  end

  @doc """
  Returns the icon path for a provider type.
  """
  def provider_icon(provider_type) do
    case provider_type do
      :openai -> "/images/openai-icon.svg"
      :anthropic -> "/images/anthropic-icon.svg"
      :ollama -> "/images/ollama-icon.svg"
      _ -> nil
    end
  end

  # Private functions

  defp encode_params([]), do: []

  defp encode_params(params) do
    for {key, value} <- params do
      if is_list(value) do
        {key, Enum.join(value, ",")}
      else
        {key, value}
      end
    end
  end
end
