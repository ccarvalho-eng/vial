defmodule Aludel.LLM do
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

  @type document_input :: %{
          data: binary(),
          content_type: String.t()
        }

  @type llm_result :: %{
          output: String.t(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          latency_ms: non_neg_integer(),
          cost_usd: float()
        }

  alias Aludel.Providers.Provider
  alias Aludel.Interfaces.LLM.Providers.{Anthropic, OpenAI, Ollama}

  @providers %{
    openai: OpenAI,
    anthropic: Anthropic,
    ollama: Ollama
  }

  @type error_reason ::
          :missing_api_key
          | {:auth_error, String.t()}
          | {:rate_limit, non_neg_integer() | nil}
          | {:invalid_request, String.t()}
          | {:api_error, non_neg_integer(), String.t()}
          | {:network_error, term()}

  @doc """
  Calls an LLM provider with a prompt and optional documents.

  ## Parameters
    - provider: Provider configuration struct
    - prompt: Text prompt to send to the LLM
    - opts: Additional options
      - :documents - List of document maps with :data and
        :content_type

  ## Returns
    - `{:ok, result}` with output, tokens, latency, and cost
    - `{:error, reason}` if the call fails

  ## Examples

      iex> provider = %Provider{provider: :openai,
      ...>   model: "gpt-4o"}
      iex> {:ok, result} = LLM.call(provider, "Hello world")
      iex> is_binary(result.output)
      true

      iex> provider = %Provider{provider: :openai,
      ...>   model: "gpt-4o"}
      iex> doc = %{data: <<...>>, content_type: "image/png"}
      iex> {:ok, result} = LLM.call(provider,
      ...>   "Describe image", documents: [doc])
      iex> is_binary(result.output)
      true
  """
  @spec call(Provider.t(), String.t(), keyword()) ::
          {:ok, llm_result()} | {:error, error_reason()}
  def call(%Provider{} = provider, prompt, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    provider_module = get_provider(provider.provider)
    config = build_config(provider)

    result = provider_module.generate(provider.model, prompt, config, opts)

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

  defp get_provider(provider_name), do: Map.fetch!(@providers, provider_name)

  defp build_config(provider) do
    base_config = provider.config || %{}

    api_key =
      case provider.provider do
        :openai -> get_openai_api_key()
        :anthropic -> get_anthropic_api_key()
        :ollama -> nil
      end

    case api_key do
      {:ok, key} -> Map.put(base_config, "api_key", key)
      _ -> base_config
    end
  end

  defp get_openai_api_key do
    case Application.get_env(:aludel, :llm)[:openai_api_key] do
      nil -> :error
      "" -> :error
      api_key -> {:ok, api_key}
    end
  end

  defp get_anthropic_api_key do
    case Application.get_env(:aludel, :llm)[:anthropic_api_key] do
      nil -> :error
      "" -> :error
      api_key -> {:ok, api_key}
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
end
