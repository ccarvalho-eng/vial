defmodule Aludel.LLM.Adapters.Anthropic do
  @moduledoc """
  Anthropic Claude API adapter implementation using ReqLLM.
  """

  @behaviour Aludel.LLM.Adapter

  @impl true
  def generate(model, prompt, config, _opts) do
    with {:ok, api_key} <- get_api_key(config) do
      req_opts = [
        api_key: api_key,
        temperature: config["temperature"] || 0.5,
        max_tokens: config["max_tokens"] || 1024
      ]

      model_spec = "anthropic:#{model}"

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
  end

  defp get_api_key(%{"api_key" => key}) when is_binary(key) and key != "", do: {:ok, key}
  defp get_api_key(_), do: {:error, :missing_api_key}

  defp parse_error(%{status: 401} = _error), do: {:error, {:auth_error, "Invalid API key"}}
  defp parse_error(%{status: 429} = _error), do: {:error, {:rate_limit, nil}}

  defp parse_error(%{status: status} = _error) when status in [400, 404],
    do: {:error, {:invalid_request, "Invalid request"}}

  defp parse_error(%{status: status} = error),
    do: {:error, {:api_error, status, inspect(error)}}

  defp parse_error(reason), do: {:error, {:network_error, reason}}
end
