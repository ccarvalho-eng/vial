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
  Returns the icon path for a provider name or type.
  Accepts both atoms (:openai) and strings ("OpenAI", "openai").
  """
  def provider_icon(provider_name) when is_binary(provider_name) do
    name_lower = String.downcase(provider_name)

    cond do
      String.contains?(name_lower, "openai") ->
        "/images/open-ai-icon.svg"

      String.contains?(name_lower, "anthropic") or String.contains?(name_lower, "claude") ->
        "/images/anthropic-icon.svg"

      String.contains?(name_lower, "ollama") ->
        "/images/ollama-icon.svg"

      String.contains?(name_lower, "gemini") ->
        "/images/gemini-icon.svg"

      String.contains?(name_lower, "grok") ->
        "/images/grok-icon.svg"

      String.contains?(name_lower, "perplexity") ->
        "/images/perplexity-ai-icon.svg"

      String.contains?(name_lower, "google") ->
        "/images/google-ai-studio-icon.svg"

      true ->
        nil
    end
  end

  def provider_icon(provider_type) when is_atom(provider_type) do
    case provider_type do
      :openai -> "/images/open-ai-icon.svg"
      :anthropic -> "/images/anthropic-icon.svg"
      :ollama -> "/images/ollama-icon.svg"
      :gemini -> "/images/gemini-icon.svg"
      :grok -> "/images/grok-icon.svg"
      :perplexity -> "/images/perplexity-ai-icon.svg"
      :google -> "/images/google-ai-studio-icon.svg"
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
