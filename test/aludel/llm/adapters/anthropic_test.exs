defmodule Aludel.LLM.Adapters.AnthropicTest do
  use ExUnit.Case, async: true

  import Mox

  alias Aludel.LLM.Adapters.Anthropic

  setup :verify_on_exit!

  describe "generate/4" do
    test "returns successful response with tokens" do
      model = "claude-sonnet-4-6"
      prompt = "Say hello"
      config = %{"temperature" => 0.5, "max_tokens" => 100, "api_key" => "test-key"}

      mock_response = %{
        status: 200,
        body: %{
          "content" => [%{"text" => "Hello! How may I assist you today?"}],
          "usage" => %{"input_tokens" => 5, "output_tokens" => 10}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = Anthropic.generate(model, prompt, config, [])
      assert response.content == "Hello! How may I assist you today?"
      assert response.input_tokens == 5
      assert response.output_tokens == 10
    end

    test "returns error when API key is missing" do
      model = "claude-sonnet-4-6"
      prompt = "test"
      config = %{}

      assert {:error, :missing_api_key} = Anthropic.generate(model, prompt, config, [])
    end

    test "handles vision models with documents" do
      model = "claude-3-5-sonnet"
      prompt = "What is this?"
      config = %{"max_tokens" => 500, "api_key" => "test-key"}

      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      mock_response = %{
        status: 200,
        body: %{
          "content" => [%{"text" => "This is a red pixel"}],
          "usage" => %{"input_tokens" => 100, "output_tokens" => 20}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = Anthropic.generate(model, prompt, config, documents: [document])
      assert response.content == "This is a red pixel"
    end

    test "returns auth error for invalid API key" do
      model = "claude-sonnet-4-6"
      prompt = "test"
      config = %{"api_key" => "invalid-key"}

      mock_response = %{
        status: 401,
        body: %{"error" => %{"message" => "Invalid API key"}}
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:error, {:auth_error, "Invalid API key"}} =
               Anthropic.generate(model, prompt, config, [])
    end

    test "returns invalid_request error for bad model" do
      model = "invalid-model"
      prompt = "test"
      config = %{"api_key" => "test-key"}

      mock_response = %{
        status: 400,
        body: %{"error" => %{"message" => "Invalid model"}}
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:error, {:invalid_request, "Invalid model"}} =
               Anthropic.generate(model, prompt, config, [])
    end

    test "handles network errors" do
      model = "claude-sonnet-4-6"
      prompt = "test"
      config = %{"api_key" => "test-key"}

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert {:error, {:network_error, :timeout}} = Anthropic.generate(model, prompt, config, [])
    end
  end
end
