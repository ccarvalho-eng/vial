defmodule Aludel.LlmStubs do
  @moduledoc """
  Centralized LLM stub responses for testing.

  Provides organized, reusable mock responses for different scenarios.
  """

  @doc """
  Default successful response for simple tests.
  """
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
  def auth_error do
    {:error, {:auth_error, "Invalid API key"}}
  end

  @doc """
  Network timeout error response.
  """
  def timeout_error do
    {:error, {:network_error, :timeout}}
  end

  @doc """
  Rate limit error response.
  """
  def rate_limit_error do
    {:error, {:rate_limit_error, "Rate limit exceeded. Retry after 60s"}}
  end

  @doc """
  Generic API error response.
  """
  def api_error(message \\ "API request failed") do
    {:error, {:api_error, message}}
  end

  @doc """
  Malformed response error.
  """
  def malformed_response_error do
    {:error, {:api_error, "Unexpected response format"}}
  end

  @doc """
  Connection refused error (for Ollama local tests).
  """
  def connection_refused_error do
    {:error, {:network_error, :econnrefused}}
  end

  @doc """
  Sets up default stub with success response.
  Call this in test setup to provide fallback behavior.
  """
  def setup_default_stub(mock_module) do
    Mox.stub(mock_module, :request, fn _model, _prompt, _opts ->
      success_response()
    end)
  end

  @doc """
  Sets up stub for specific provider with custom response.
  """
  def stub_provider_response(mock_module, provider, response_fn)
      when is_function(response_fn, 3) do
    Mox.stub(mock_module, :request, fn model, prompt, opts ->
      response_fn.(model, prompt, opts)
    end)
  end

  @doc """
  Stub that returns different responses based on prompt content.
  Useful for testing evaluation scenarios.
  """
  def stub_conditional_responses(mock_module, conditions) do
    Mox.stub(mock_module, :request, fn _model, prompt, _opts ->
      Enum.find_value(conditions, success_response(), fn {pattern, response} ->
        if String.contains?(prompt, pattern), do: response
      end)
    end)
  end
end
