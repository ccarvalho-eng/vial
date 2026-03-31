defmodule Aludel.Interfaces.LLM.Adapters.Http.Default do
  @moduledoc """
  Default LLM HTTP client using ReqLLM.

  Uses the ReqLLM library for making LLM API calls, normalizing
  responses to a generic format that hides ReqLLM-specific types.

  ## Telemetry

  Emits the following telemetry events:

  * `[:aludel, :llm, :http, :start]` - When an HTTP request begins
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{model_spec: String.t()}`

  * `[:aludel, :llm, :http, :stop]` - When an HTTP request completes
    - Measurements: `%{duration: integer(), input_tokens: integer(),
      output_tokens: integer()}`
    - Metadata: `%{model_spec: String.t()}`

  * `[:aludel, :llm, :http, :exception]` - When an HTTP request fails
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{model_spec: String.t(), error: term()}`
  """

  alias Aludel.Interfaces.Adapters.Http
  alias ReqLLM.Message.ContentPart

  require Logger

  @behaviour Http

  @doc """
  LLM-specific HTTP call using ReqLLM.

  ## Parameters
    - model_spec: Provider and model (e.g., "openai:gpt-4o")
    - messages: Text prompt or message list
    - opts: LLM options (api_key, temperature, max_tokens, documents)

  ## Returns
    - `{:ok, %{content: String.t(), input_tokens: integer(),
      output_tokens: integer()}}`
    - `{:error, reason}`
  """
  @impl Http
  def request(model_spec, messages, opts) do
    start_time = System.monotonic_time()
    metadata = %{model_spec: model_spec}

    :telemetry.execute(
      [:aludel, :llm, :http, :start],
      %{system_time: System.system_time()},
      metadata
    )

    {documents, req_opts} = Keyword.pop(opts, :documents, [])
    formatted_messages = format_messages(model_spec, messages, documents)

    case ReqLLM.generate_text(model_spec, formatted_messages, req_opts) do
      {:ok, response} ->
        usage = ReqLLM.Response.usage(response)
        content = ReqLLM.Response.text(response)
        duration = System.monotonic_time() - start_time

        normalized_response = %{
          content: content,
          input_tokens: usage.input_tokens || 0,
          output_tokens: usage.output_tokens || 0
        }

        :telemetry.execute(
          [:aludel, :llm, :http, :stop],
          %{
            duration: duration,
            input_tokens: normalized_response.input_tokens,
            output_tokens: normalized_response.output_tokens
          },
          metadata
        )

        {:ok, normalized_response}

      {:error, reason} = error ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:aludel, :llm, :http, :exception],
          %{duration: duration},
          Map.put(metadata, :error, reason)
        )

        error
    end
  end

  defp format_messages(_model_spec, prompt, []) when is_binary(prompt), do: prompt

  defp format_messages(model_spec, prompt, documents) when is_binary(prompt) do
    provider = extract_provider(model_spec)

    content_parts =
      [ContentPart.text(prompt)] ++
        Enum.flat_map(documents, &to_content_part(&1, provider))

    message = ReqLLM.Context.user(content_parts)
    ReqLLM.Context.new([message])
  end

  defp format_messages(_model_spec, messages, _documents), do: messages

  defp extract_provider(model_spec), do: model_spec |> String.split(":") |> hd()

  # Anthropic and OpenAI support PDFs natively
  defp to_content_part(%{content_type: "application/pdf", data: data}, provider)
       when provider in ["anthropic", "openai"] do
    [ContentPart.file(data, "document.pdf", "application/pdf")]
  end

  # Ollama needs PDFs converted to images
  defp to_content_part(%{content_type: "application/pdf"} = doc, _provider) do
    case Aludel.DocumentConverter.pdf_to_image(doc) do
      {:ok, converted} -> to_image_part(converted.data, converted.content_type)
      {:error, reason} -> log_conversion_error(reason)
    end
  end

  # Images work for all providers
  defp to_content_part(%{content_type: "image/" <> _ = type, data: data}, _) do
    to_image_part(data, type)
  end

  defp to_content_part(_doc, _provider), do: []

  defp to_image_part(data, content_type) do
    data_url = "data:#{content_type};base64,#{Base.encode64(data)}"
    [ContentPart.image_url(data_url)]
  end

  defp log_conversion_error(reason) do
    Logger.error("Failed to convert PDF to image: #{inspect(reason)}")
    []
  end
end
