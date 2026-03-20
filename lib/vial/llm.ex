defmodule Vial.LLM do
  @moduledoc """
  LLM client abstraction for multi-provider support.

  Supports OpenAI, Anthropic, and Ollama providers via direct HTTP calls.
  Provides unified interface for generating text completions and tracking usage metrics.

  Returns structured responses containing:
  - Generated output text
  - Token usage (input/output)
  - Latency measurements
  - Cost estimation
  """

  @type llm_result :: %{
          output: String.t(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          latency_ms: non_neg_integer(),
          cost_usd: float()
        }

  alias Vial.Providers.Provider

  @type error_reason ::
          :missing_api_key
          | {:auth_error, String.t()}
          | {:rate_limit, non_neg_integer() | nil}
          | {:invalid_request, String.t()}
          | {:api_error, non_neg_integer(), String.t()}
          | {:network_error, term()}

  @doc """
  Calls an LLM provider with a prompt and returns structured result.

  ## Parameters
    - provider: Provider configuration struct
    - prompt: Text prompt to send to the LLM
    - opts: Additional options (reserved for future use)

  ## Returns
    - `{:ok, result}` with output, tokens, latency, and cost
    - `{:error, reason}` if the call fails

  ## Examples

      iex> provider = %Provider{provider: :openai, model: "gpt-4o"}
      iex> {:ok, result} = LLM.call(provider, "Hello world")
      iex> is_binary(result.output)
      true
  """
  @spec call(Provider.t(), String.t(), keyword()) ::
          {:ok, llm_result()} | {:error, error_reason()}
  def call(%Provider{} = provider, prompt, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case provider.provider do
        :openai -> generate_openai(provider, prompt, opts)
        :anthropic -> generate_anthropic(provider, prompt, opts)
        :ollama -> generate_ollama(provider, prompt, opts)
      end

    case result do
      {:ok, response} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           output: response.content,
           input_tokens: response.input_tokens,
           output_tokens: response.output_tokens,
           latency_ms: latency_ms,
           cost_usd: calculate_cost(provider, response)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private implementation functions

  defp generate_openai(_provider, prompt, _opts) do
    # Mock implementation for V1 - will integrate real LangChain later
    # Real implementation would use:
    # model = LangChain.ChatModels.ChatOpenAI.new!(%{
    #   model: provider.model,
    #   temperature: get_in(provider.config, ["temperature"]) || 0.7
    # })
    # LangChain.Chains.LLMChain.run(model, prompt)

    # Simulate processing time
    Process.sleep(1)

    input_tokens = estimate_tokens(prompt)
    output_tokens = 20

    {:ok,
     %{
       content: "Mock OpenAI response for: #{prompt}",
       input_tokens: input_tokens,
       output_tokens: output_tokens
     }}
  end

  defp generate_anthropic(provider, prompt, _opts) do
    case Application.get_env(:vial, :llm)[:anthropic_api_key] do
      nil ->
        {:error, :missing_api_key}

      "" ->
        {:error, :missing_api_key}

      api_key ->
        url = "https://api.anthropic.com/v1/messages"

        body = %{
          model: provider.model,
          messages: [%{role: "user", content: prompt}],
          temperature: get_in(provider.config, ["temperature"]) || 0.5,
          max_tokens: get_in(provider.config, ["max_tokens"]) || 1024
        }

        headers = [
          {"x-api-key", api_key},
          {"anthropic-version", "2023-06-01"},
          {"content-type", "application/json"}
        ]

        case Req.post(url, json: body, headers: headers) do
          {:ok, %{status: 200, body: response}} ->
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

          {:ok, %{status: 401, body: body}} ->
            message = get_in(body, ["error", "message"]) || "Invalid API key"
            {:error, {:auth_error, message}}

          {:ok, %{status: 429, headers: headers}} ->
            retry_after =
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

            {:error, {:rate_limit, retry_after}}

          {:ok, %{status: status, body: body}} when status in [400, 404] ->
            message = get_in(body, ["error", "message"]) || "Invalid request"
            {:error, {:invalid_request, message}}

          {:ok, %{status: status, body: body}} ->
            message = get_in(body, ["error", "message"]) || inspect(body)
            {:error, {:api_error, status, message}}

          {:error, reason} ->
            {:error, {:network_error, reason}}
        end
    end
  end

  defp generate_ollama(provider, prompt, _opts) do
    # Ollama provides OpenAI-compatible API at /v1/chat/completions
    # Using direct Req since req_llm requires API key validation
    url = "http://localhost:11434/v1/chat/completions"

    body = %{
      model: provider.model,
      messages: [
        %{role: "user", content: prompt}
      ],
      stream: false,
      temperature: get_in(provider.config, ["temperature"]) || 0.8
    }

    case Req.post(url, json: body) do
      {:ok, %{status: 200, body: response}} ->
        message = get_in(response, ["choices", Access.at(0), "message", "content"])
        usage = response["usage"]

        {:ok,
         %{
           content: message,
           input_tokens: usage["prompt_tokens"] || 0,
           output_tokens: usage["completion_tokens"] || 0
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Ollama API error: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to connect to Ollama: #{inspect(reason)}"}
    end
  end

  defp calculate_cost(provider, response) do
    case provider.provider do
      :openai ->
        # OpenAI GPT-4o pricing: $5/million input, $15/million output
        input_cost = response.input_tokens * 5.0 / 1_000_000
        output_cost = response.output_tokens * 15.0 / 1_000_000
        Float.round(input_cost + output_cost, 6)

      :anthropic ->
        # Anthropic Claude pricing: $3/million input, $15/million output
        input_cost = response.input_tokens * 3.0 / 1_000_000
        output_cost = response.output_tokens * 15.0 / 1_000_000
        Float.round(input_cost + output_cost, 6)

      :ollama ->
        # Ollama is local, no cost
        0.0
    end
  end

  defp estimate_tokens(text) do
    # Simple estimation: ~4 chars per token (rough GPT approximation)
    # Real implementation would use tiktoken or similar
    max(1, div(String.length(text), 4))
  end
end
