defmodule Aludel.LLM.Adapters.Ollama do
  @moduledoc """
  Ollama API adapter implementation.

  Ollama doesn't require authentication, so we pass a random string
  as api_key to reqllm.
  """

  @behaviour Aludel.LLM.Adapter

  alias Aludel.DocumentConverter
  alias Aludel.LLM.HTTPClient

  @vision_models ~w(llava bakllava)

  @impl true
  def generate(model, prompt, config, opts) do
    response = make_request(model, prompt, config, opts)
    parse_response(response)
  end

  defp make_request(model, prompt, config, opts) do
    url = "http://localhost:11434/v1/chat/completions"
    documents = Keyword.get(opts, :documents, [])

    content =
      if documents != [] and vision_model?(model) do
        converted_docs =
          Enum.map(documents, fn doc ->
            case DocumentConverter.pdf_to_image(doc) do
              {:ok, converted} -> converted
              {:error, _reason} -> doc
            end
          end)

        build_vision_content(prompt, converted_docs)
      else
        prompt
      end

    body = %{
      model: model,
      messages: [%{role: "user", content: content}],
      stream: false,
      temperature: config["temperature"] || 0.8
    }

    HTTPClient.post(url, json: body)
  end

  defp vision_model?(model) do
    Enum.any?(@vision_models, &String.starts_with?(model, &1))
  end

  defp build_vision_content(prompt, documents) do
    text_part = %{type: "text", text: prompt}

    image_parts =
      Enum.map(documents, fn doc ->
        %{
          type: "image_url",
          image_url: %{
            url: "data:#{doc.content_type};base64,#{Base.encode64(doc.data)}"
          }
        }
      end)

    [text_part | image_parts]
  end

  defp parse_response({:ok, %{status: 200, body: response}}) do
    message = get_in(response, ["choices", Access.at(0), "message", "content"])
    usage = response["usage"]

    {:ok,
     %{
       content: message,
       input_tokens: usage["prompt_tokens"] || 0,
       output_tokens: usage["completion_tokens"] || 0
     }}
  end

  defp parse_response({:ok, %{status: status, body: body}}) do
    {:error, {:api_error, status, inspect(body)}}
  end

  defp parse_response({:error, reason}) do
    {:error, {:network_error, reason}}
  end
end
