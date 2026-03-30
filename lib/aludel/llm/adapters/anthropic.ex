defmodule Aludel.LLM.Adapters.Anthropic do
  @moduledoc """
  Anthropic Claude API adapter implementation.
  """

  @behaviour Aludel.LLM.Adapter

  alias Aludel.LLM.HTTPClient

  @vision_models ~w(claude-sonnet-4 claude-haiku-4 claude-opus-4 claude-3-5-sonnet claude-3-opus claude-3-sonnet claude-3-haiku)

  @impl true
  def generate(model, prompt, config, opts) do
    with {:ok, api_key} <- get_api_key(config),
         response <- make_request(model, prompt, api_key, config, opts) do
      parse_response(response)
    end
  end

  defp get_api_key(%{"api_key" => key}) when is_binary(key) and key != "", do: {:ok, key}
  defp get_api_key(_), do: {:error, :missing_api_key}

  defp make_request(model, prompt, api_key, config, opts) do
    url = "https://api.anthropic.com/v1/messages"
    documents = Keyword.get(opts, :documents, [])

    content =
      if documents != [] and vision_model?(model) do
        build_document_content(prompt, documents)
      else
        prompt
      end

    body = %{
      model: model,
      messages: [%{role: "user", content: content}],
      temperature: config["temperature"] || 0.5,
      max_tokens: config["max_tokens"] || 1024
    }

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    HTTPClient.post(url, json: body, headers: headers, receive_timeout: 60_000)
  end

  defp vision_model?(model) do
    Enum.any?(@vision_models, &String.starts_with?(model, &1))
  end

  defp build_document_content(prompt, documents) do
    text_content = %{"type" => "text", "text" => prompt}

    doc_contents =
      Enum.map(documents, fn doc ->
        content_type =
          if doc.content_type == "application/pdf" do
            "document"
          else
            "image"
          end

        %{
          "type" => content_type,
          "source" => %{
            "type" => "base64",
            "media_type" => doc.content_type,
            "data" => Base.encode64(doc.data)
          }
        }
      end)

    [text_content | doc_contents]
  end

  defp parse_response({:ok, %{status: 200, body: response}}) do
    content = get_in(response, ["content", Access.at(0), "text"])

    if content do
      usage = response["usage"]

      {:ok,
       %{
         content: content,
         input_tokens: usage["input_tokens"] || 0,
         output_tokens: usage["output_tokens"] || 0
       }}
    else
      {:error, {:api_error, 200, "Unexpected response structure: missing content"}}
    end
  end

  defp parse_response({:ok, %{status: 401, body: body}}) do
    message = get_in(body, ["error", "message"]) || "Invalid API key"
    {:error, {:auth_error, message}}
  end

  defp parse_response({:ok, %{status: 429, headers: headers}}) do
    retry_after = parse_retry_after_header(headers)
    {:error, {:rate_limit, retry_after}}
  end

  defp parse_response({:ok, %{status: status, body: body}}) when status in [400, 404] do
    message = get_in(body, ["error", "message"]) || "Invalid request"
    {:error, {:invalid_request, message}}
  end

  defp parse_response({:ok, %{status: status, body: body}}) do
    message = get_in(body, ["error", "message"]) || inspect(body)
    {:error, {:api_error, status, message}}
  end

  defp parse_response({:error, reason}) do
    {:error, {:network_error, reason}}
  end

  defp parse_retry_after_header(headers) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == "retry-after" end)
    |> case do
      {_, value} ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> nil
        end

      nil ->
        nil
    end
  end
end
