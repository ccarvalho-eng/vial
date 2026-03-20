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
          {:ok, llm_result()} | {:error, term()}
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

  defp generate_anthropic(_provider, prompt, _opts) do
    # Mock implementation for V1 - will integrate real LangChain later
    # Real implementation would use:
    # model = LangChain.ChatModels.ChatAnthropic.new!(%{
    #   model: provider.model,
    #   temperature: get_in(provider.config, ["temperature"]) || 0.5
    # })
    # LangChain.Chains.LLMChain.run(model, prompt)

    # Simulate processing time
    Process.sleep(1)

    input_tokens = estimate_tokens(prompt)
    output_tokens = 25

    {:ok,
     %{
       content: "Mock Anthropic response for: #{prompt}",
       input_tokens: input_tokens,
       output_tokens: output_tokens
     }}
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
        # OpenAI GPT-4o pricing: ~$0.005/1k input, ~$0.015/1k output
        input_cost = response.input_tokens * 0.005 / 1000
        output_cost = response.output_tokens * 0.015 / 1000
        Float.round(input_cost + output_cost, 6)

      :anthropic ->
        # Anthropic Claude pricing: ~$0.003/1k input, ~$0.015/1k output
        input_cost = response.input_tokens * 0.003 / 1000
        output_cost = response.output_tokens * 0.015 / 1000
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
