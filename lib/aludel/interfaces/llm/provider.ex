defmodule Aludel.Interfaces.LLM.Provider do
  @moduledoc """
  Shared utilities for LLM provider implementations.
  """

  @doc """
  Returns the configured HTTP client for making LLM API calls.
  """
  def http_client do
    Application.get_env(
      :aludel,
      :http_client,
      Aludel.Interfaces.LLM.Adapters.Http.Default
    )
  end

  @doc """
  Extracts and validates API key from provider config.

  Returns `{:ok, key}` if valid, `{:error, :missing_api_key}` otherwise.
  """
  def get_api_key(%{"api_key" => key}) when is_binary(key) and key != "",
    do: {:ok, key}

  def get_api_key(_), do: {:error, :missing_api_key}
end
