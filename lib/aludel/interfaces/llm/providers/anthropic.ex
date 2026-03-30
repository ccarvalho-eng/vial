defmodule Aludel.Interfaces.LLM.Providers.Anthropic do
  @moduledoc """
  Anthropic Claude API adapter implementation.

  Handles API communication with Anthropic's Claude models through the
  configured HTTP adapter.
  """

  alias Aludel.Interfaces.LLM.{Config, ErrorParser}

  @behaviour Aludel.Interfaces.LLM.Behaviour

  @impl true
  def generate(model, prompt, config, _opts) do
    with {:ok, api_key} <- Config.get_api_key(config) do
      req_opts = [
        api_key: api_key,
        temperature: config["temperature"] || 0.5,
        max_tokens: config["max_tokens"] || 1024
      ]

      model_spec = "anthropic:#{model}"

      case Config.http_adapter().request(model_spec, prompt, req_opts) do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          ErrorParser.parse_error(reason)
      end
    end
  end
end
