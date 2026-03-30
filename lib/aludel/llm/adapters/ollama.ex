defmodule Aludel.LLM.Adapters.Ollama do
  @moduledoc """
  Ollama API adapter implementation using ReqLLM.

  Ollama doesn't require authentication, so we pass a random string
  as api_key to ReqLLM.
  """

  @behaviour Aludel.LLM.Adapter

  @impl true
  def generate(model, prompt, config, _opts) do
    req_opts = [
      api_key: "ollama-no-auth-required",
      base_url: "http://localhost:11434/v1",
      temperature: config["temperature"] || 0.8
    ]

    model_spec = "openai:#{model}"

    case ReqLLM.generate_text(model_spec, prompt, req_opts) do
      {:ok, response} ->
        usage = ReqLLM.Response.usage(response)
        content = ReqLLM.Response.text(response)

        {:ok,
         %{
           content: content,
           input_tokens: usage.input_tokens || 0,
           output_tokens: usage.output_tokens || 0
         }}

      {:error, reason} ->
        parse_error(reason)
    end
  end

  defp parse_error(%{status: status} = error), do: {:error, {:api_error, status, inspect(error)}}
  defp parse_error(reason), do: {:error, {:network_error, reason}}
end
