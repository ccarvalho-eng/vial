defmodule Aludel.LLM.Adapters.OpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias Aludel.LLM.Adapters.OpenAI

  setup :verify_on_exit!

  describe "generate/4" do
    test "returns successful response with tokens using mocked HTTP client" do
      model = "gpt-4o"
      prompt = "Say hello"
      config = %{"temperature" => 0.7, "max_tokens" => 100, "api_key" => "test-key"}

      mock_response = %{
        status: 200,
        body: %{
          "choices" => [
            %{"message" => %{"content" => "Hello! How can I assist you today?"}}
          ],
          "usage" => %{
            "prompt_tokens" => 5,
            "completion_tokens" => 10
          }
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = OpenAI.generate(model, prompt, config, [])
      assert response.content == "Hello! How can I assist you today?"
      assert response.input_tokens == 5
      assert response.output_tokens == 10
    end

    test "returns error when API key is missing" do
      model = "gpt-4o"
      prompt = "test"
      config = %{}

      assert {:error, :missing_api_key} = OpenAI.generate(model, prompt, config, [])
    end

    test "handles vision models with documents using mocked client" do
      model = "gpt-4o"
      prompt = "What is this?"
      config = %{"max_tokens" => 500, "api_key" => "test-key"}

      # 1x1 red PNG
      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      mock_response = %{
        status: 200,
        body: %{
          "choices" => [%{"message" => %{"content" => "This is a red pixel"}}],
          "usage" => %{"prompt_tokens" => 100, "completion_tokens" => 20}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = OpenAI.generate(model, prompt, config, documents: [document])
      assert response.content == "This is a red pixel"
    end

    test "returns auth error for invalid API key using mocked client" do
      model = "gpt-4o"
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
               OpenAI.generate(model, prompt, config, [])
    end

    test "returns invalid_request error for bad model using mocked client" do
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
               OpenAI.generate(model, prompt, config, [])
    end

    test "handles network errors using mocked client" do
      model = "gpt-4o"
      prompt = "test"
      config = %{"api_key" => "test-key"}

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert {:error, {:network_error, :timeout}} = OpenAI.generate(model, prompt, config, [])
    end
  end
end
