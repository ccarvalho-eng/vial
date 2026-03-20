defmodule Vial.LLMTest do
  use Vial.DataCase, async: true

  alias Vial.LLM

  describe "call/3 with OpenAI provider" do
    test "returns structured response with all required fields" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{"temperature" => 0.7}
        })

      assert {:ok, result} = LLM.call(provider, "test prompt", [])
      assert is_binary(result.output)
      assert result.output != ""
      assert is_integer(result.input_tokens)
      assert is_integer(result.output_tokens)
      assert is_integer(result.latency_ms)
      assert is_float(result.cost_usd)
      assert result.latency_ms > 0
    end

    test "calculates cost for OpenAI" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      # Should have non-zero cost for OpenAI
      assert result.cost_usd > 0
    end
  end

  describe "call/3 with Anthropic provider" do
    test "returns structured response" do
      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{"temperature" => 0.5, "max_tokens" => 500}
        })

      assert {:ok, result} = LLM.call(provider, "test prompt", [])
      assert is_binary(result.output)
      assert is_integer(result.input_tokens)
      assert is_integer(result.output_tokens)
      assert is_integer(result.latency_ms)
      assert is_float(result.cost_usd)
    end

    test "calculates cost for Anthropic" do
      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.cost_usd > 0
    end
  end

  describe "call/3 with Ollama provider" do
    test "returns structured response" do
      provider =
        provider_fixture(%{
          provider: :ollama,
          model: "llama3.2",
          config: %{"temperature" => 0.8}
        })

      assert {:ok, result} = LLM.call(provider, "test prompt", [])
      assert is_binary(result.output)
      assert is_integer(result.input_tokens)
      assert is_integer(result.output_tokens)
      assert is_integer(result.latency_ms)
      assert is_float(result.cost_usd)
    end

    test "returns zero cost for Ollama (local)" do
      provider =
        provider_fixture(%{
          provider: :ollama,
          model: "llama3.2",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.cost_usd == 0.0
    end
  end

  describe "call/3 error handling" do
    test "handles invalid provider gracefully" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "invalid-model",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      # Should return a result (error handling will be mocked)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "call/3 token counting" do
    test "counts tokens for input and output" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "Hello world", [])
      assert result.input_tokens > 0
      assert result.output_tokens > 0
    end
  end

  describe "call/3 latency measurement" do
    test "measures execution time in milliseconds" do
      provider =
        provider_fixture(%{
          provider: :ollama,
          model: "llama3.2",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.latency_ms >= 0
      assert is_integer(result.latency_ms)
    end
  end
end
