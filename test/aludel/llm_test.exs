defmodule Aludel.LLMTest do
  use Aludel.DataCase, async: true

  import Mox

  alias Aludel.LLM

  setup :verify_on_exit!

  defp build_mock_response(text, input_tokens, output_tokens) do
    %ReqLLM.Response{
      id: "test-id",
      model: "test-model",
      context: [
        %{role: "user", content: "test"},
        %{role: "assistant", content: [%{type: "text", text: text}]}
      ],
      message: %ReqLLM.Message{
        role: :assistant,
        content: [%{type: :text, text: text}]
      },
      finish_reason: :stop,
      usage: %{
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: input_tokens + output_tokens
      },
      error: nil,
      object: nil,
      provider_meta: %{},
      stream: nil,
      stream?: false
    }
  end

  describe "call/3 with OpenAI provider" do
    test "returns error when API key is missing" do
      original_config = Application.get_env(:aludel, :llm)
      Application.put_env(:aludel, :llm, openai_api_key: nil)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      Application.put_env(:aludel, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns error when API key is empty string" do
      original_config = Application.get_env(:aludel, :llm)
      Application.put_env(:aludel, :llm, openai_api_key: "")

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      Application.put_env(:aludel, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns structured response with all required fields" do
      mock_response = build_mock_response("Hello! How can I help?", 5, 10)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

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
      assert result.latency_ms >= 0
    end

    test "calculates cost for OpenAI" do
      mock_response = build_mock_response("Test response", 5, 10)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.cost_usd > 0
    end

    test "calls OpenAI adapter successfully" do
      mock_response = build_mock_response("Hello!", 3, 2)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

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

    test "returns auth error for invalid API key" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, %{status: 401}}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert {:error, {:auth_error, _message}} = result
    end

    test "returns invalid_request error for bad parameters" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, %{status: 400}}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "invalid-model-name",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert {:error, {:invalid_request, _}} = result
    end
  end

  describe "call/3 with Anthropic provider" do
    test "returns error when API key is missing" do
      # Temporarily clear the config
      original_config = Application.get_env(:aludel, :llm)
      Application.put_env(:aludel, :llm, anthropic_api_key: nil)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      # Restore original config
      Application.put_env(:aludel, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns error when API key is empty string" do
      original_config = Application.get_env(:aludel, :llm)
      Application.put_env(:aludel, :llm, anthropic_api_key: "")

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet-20241022",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      # Restore original config
      Application.put_env(:aludel, :llm, original_config)

      assert {:error, :missing_api_key} = result
    end

    test "returns structured response" do
      mock_response = build_mock_response("Hello! I'm Claude.", 8, 6)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

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

    test "calculates cost for Anthropic" do
      mock_response = build_mock_response("Test response", 5, 10)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          config: %{}
        })

      {:ok, result} = LLM.call(provider, "test", [])
      assert result.cost_usd > 0
    end

    test "returns auth error for invalid API key" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, %{status: 401}}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert {:error, {:auth_error, _message}} = result
    end

    test "returns invalid_request error for bad parameters" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, %{status: 400}}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "invalid-model",
          config: %{}
        })

      result = LLM.call(provider, "test", [])

      assert {:error, {:invalid_request, _}} = result
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
    test "handles network errors gracefully" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, :timeout}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "test", [])
      assert {:error, {:network_error, :timeout}} = result
    end
  end

  describe "call/3 token counting" do
    test "counts tokens for input and output" do
      mock_response = build_mock_response("Response", 10, 15)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

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
      mock_response = build_mock_response("Response", 5, 5)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

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
