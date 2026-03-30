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

  @behaviour Http

  @doc """
  LLM-specific HTTP call using ReqLLM.

  ## Parameters
    - model_spec: Provider and model (e.g., "openai:gpt-4o")
    - messages: Text prompt or message list
    - opts: LLM options (api_key, temperature, max_tokens)

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

    case ReqLLM.generate_text(model_spec, messages, opts) do
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
end
