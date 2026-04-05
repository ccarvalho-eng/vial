defmodule Aludel.LlmStubs do
  @moduledoc """
  Centralized LLM stub responses for testing.

  Provides organized, reusable mock responses for different scenarios.
  """

  @type llm_response :: {:ok, map()} | {:error, tuple()}

  @doc """
  Default successful response for simple tests.
  """
  @spec success_response() :: llm_response()
  def success_response do
    {:ok,
     %{
       content: "Test response",
       input_tokens: 10,
       output_tokens: 5
     }}
  end

  @doc """
  Response for evaluation tests that need specific content.
  """
  @spec eval_response(String.t()) :: llm_response()
  def eval_response(content) do
    {:ok,
     %{
       content: content,
       input_tokens: 20,
       output_tokens: 10
     }}
  end

  @doc """
  Response with high token usage for cost calculation tests.
  """
  @spec high_usage_response() :: llm_response()
  def high_usage_response do
    {:ok,
     %{
       content: "Long detailed response " <> String.duplicate("word ", 100),
       input_tokens: 1000,
       output_tokens: 500
     }}
  end

  @doc """
  Response with minimal tokens for testing edge cases.
  """
  @spec minimal_response() :: llm_response()
  def minimal_response do
    {:ok,
     %{
       content: "Ok",
       input_tokens: 1,
       output_tokens: 1
     }}
  end

  @doc """
  Authentication error response.
  """
  @spec auth_error() :: llm_response()
  def auth_error do
    {:error, {:auth_error, "Invalid API key"}}
  end

  @doc """
  Network timeout error response.
  """
  @spec timeout_error() :: llm_response()
  def timeout_error do
    {:error, {:network_error, :timeout}}
  end

  @doc """
  Rate limit error response.
  """
  @spec rate_limit_error() :: llm_response()
  def rate_limit_error do
    {:error, {:rate_limit_error, "Rate limit exceeded. Retry after 60s"}}
  end

  @doc """
  Generic API error response.
  """
  @spec api_error(String.t()) :: llm_response()
  def api_error(message \\ "API request failed") do
    {:error, {:api_error, message}}
  end

  @doc """
  Malformed response error.
  """
  @spec malformed_response_error() :: llm_response()
  def malformed_response_error do
    {:error, {:api_error, "Unexpected response format"}}
  end

  @doc """
  Connection refused error (for Ollama local tests).
  """
  @spec connection_refused_error() :: llm_response()
  def connection_refused_error do
    {:error, {:network_error, :econnrefused}}
  end

  @doc """
  Sets up default stub with success response.
  Call this in test setup to provide fallback behavior.
  """
  @spec setup_default_stub(module()) :: :ok
  def setup_default_stub(mock_module) do
    Mox.stub(mock_module, :request, fn _model, _prompt, _opts ->
      success_response()
    end)
  end

  @doc """
  Sets up stub for specific provider with custom response.
  """
  @spec stub_provider_response(module(), atom(), function()) :: :ok
  def stub_provider_response(mock_module, _provider, response_fn)
      when is_function(response_fn, 3) do
    Mox.stub(mock_module, :request, fn model, prompt, opts ->
      response_fn.(model, prompt, opts)
    end)
  end

  @doc """
  Stub that returns different responses based on prompt content.
  Useful for testing evaluation scenarios.
  """
  @spec stub_conditional_responses(module(), [{String.t(), llm_response()}]) ::
          :ok
  def stub_conditional_responses(mock_module, conditions) do
    Mox.stub(mock_module, :request, fn _model, prompt, _opts ->
      Enum.find_value(conditions, success_response(), fn {pattern, response} ->
        match_conditional_response(prompt, pattern, response)
      end)
    end)
  end

  defp match_conditional_response(prompt, pattern, response) do
    if String.contains?(prompt, pattern), do: response
  end
end
