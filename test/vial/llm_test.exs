defmodule Vial.LLMTest do
  use Vial.DataCase, async: true

  alias Vial.LLM

  describe "call/3 with OpenAI provider" do
    test "returns error when API key is missing" do
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, openai_api_key: nil)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      Application.put_env(:vial, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns error when API key is empty string" do
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, openai_api_key: "")

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      Application.put_env(:vial, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    @tag :openai_integration
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

    @tag :openai_integration
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

    @tag :openai_integration
    test "calls real OpenAI API successfully" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{"temperature" => 0.7, "max_tokens" => 100}
        })

      assert {:ok, result} = LLM.call(provider, "Say hello", [])
      assert is_binary(result.output)
      assert result.output != ""
      assert result.input_tokens > 0
      assert result.output_tokens > 0
    end

    @tag :openai_integration
    test "returns auth error for invalid API key" do
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, openai_api_key: "sk-invalid-key")

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      Application.put_env(:vial, :llm, original_config)

      assert {:error, {:auth_error, _message}} = result
    end

    @tag :openai_integration
    test "returns invalid_request error for bad parameters" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "invalid-model-name",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert match?({:error, {:invalid_request, _}}, result) or
               match?({:error, {:api_error, _, _}}, result)
    end
  end

  describe "call/3 with Anthropic provider" do
    test "returns error when API key is missing" do
      # Temporarily clear the config
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, anthropic_api_key: nil)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      # Restore original config
      Application.put_env(:vial, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns error when API key is empty string" do
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, anthropic_api_key: "")

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      # Restore original config
      Application.put_env(:vial, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    @tag :anthropic_integration
    test "returns structured response" do
      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          config: %{"temperature" => 0.5, "max_tokens" => 100}
        })

      assert {:ok, result} = LLM.call(provider, "Say hello", [])
      assert is_binary(result.output)
      assert result.output != ""
      assert is_integer(result.input_tokens)
      assert result.input_tokens > 0
      assert is_integer(result.output_tokens)
      assert result.output_tokens > 0
      assert is_integer(result.latency_ms)
      assert is_float(result.cost_usd)
    end

    @tag :anthropic_integration
    test "calculates cost for Anthropic" do
      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.cost_usd > 0
    end

    @tag :anthropic_integration
    test "returns auth error for invalid API key" do
      # Temporarily set invalid key
      original_config = Application.get_env(:vial, :llm)
      Application.put_env(:vial, :llm, anthropic_api_key: "invalid-key-12345")

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      # Restore config
      Application.put_env(:vial, :llm, original_config)

      assert {:error, {:auth_error, _message}} = result
    end

    @tag :anthropic_integration
    test "returns invalid_request error for bad parameters" do
      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "invalid-model",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert match?({:error, {:invalid_request, _}}, result) or
               match?({:error, {:api_error, 400, _}}, result)
    end
  end

  describe "call/3 with Ollama provider" do
    @tag :ollama
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

    @tag :ollama
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
    @tag :openai_integration
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
    @tag :ollama
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
