defmodule Aludel.Interfaces.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI LLM provider implementation.

  Handles provider-specific logic (API keys, error handling) while
  delegating HTTP communication to the configured HTTP adapter.
  """

  alias Aludel.Interfaces.LLM.{ErrorParser, Utils}

  @behaviour Aludel.Interfaces.LLM.Behaviour

  @impl true
  def generate(model, prompt, config, _opts) do
    with {:ok, api_key} <- Utils.get_api_key(config) do
      req_opts = [
        api_key: api_key,
        temperature: config["temperature"] || 0.7,
        max_tokens: config["max_tokens"] || 1000
      ]

      model_spec = "openai:#{model}"

      case Utils.http_client().request(model_spec, prompt, req_opts) do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          ErrorParser.parse_error(reason)
      end
    end
  end
end
