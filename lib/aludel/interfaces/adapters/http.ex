defmodule Aludel.Interfaces.Adapters.Http do
  @moduledoc """
  Generic HTTP client adapter behaviour.

  Provides swappable HTTP client interface. Not tied to any specific
  domain (LLMs, APIs, etc.) - implementations handle domain-specific logic.
  """

  @doc """
  Performs an HTTP operation.

  Parameters and return values are intentionally generic to support
  different use cases (LLM calls, REST APIs, webhooks, etc.).

  Implementations should document their specific contracts.
  """
  @callback request(url_or_spec :: term(), payload :: term(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}
end
