defmodule Aludel.Interfaces.LLM.Providers.Ollama do
  @moduledoc """
  Ollama API adapter implementation.

  Handles API communication with local Ollama models through the
  configured HTTP adapter.

  Ollama doesn't require authentication, so we pass a random string
  as api_key to ReqLLM.
  """

  alias Aludel.Interfaces.LLM.{Config, ErrorParser}

  @behaviour Aludel.Interfaces.LLM.Behaviour

  @impl true
  def generate(model, prompt, config, _opts) do
    req_opts = [
      api_key: "ollama-no-auth-required",
      base_url: "http://localhost:11434/v1",
      temperature: config["temperature"] || 0.8
    ]

    model_spec = "openai:#{model}"

    case Config.http_adapter().request(model_spec, prompt, req_opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        ErrorParser.parse_error(reason)
    end
  end
end
