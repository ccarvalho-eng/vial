defmodule Aludel.LLM.Adapters.OllamaTest do
  use ExUnit.Case, async: true

  import Mox

  alias Aludel.LLM.Adapters.Ollama

  setup :verify_on_exit!

  describe "generate/4" do
    test "returns successful response without requiring API key" do
      model = "llama3.2"
      prompt = "Say hello"
      config = %{"temperature" => 0.8}

      mock_response = %{
        status: 200,
        body: %{
          "choices" => [%{"message" => %{"content" => "Hello!"}}],
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 2}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = Ollama.generate(model, prompt, config, [])
      assert response.content == "Hello!"
      assert response.input_tokens == 5
      assert response.output_tokens == 2
    end

    test "handles vision models with documents" do
      model = "llava"
      prompt = "What is this?"
      config = %{"temperature" => 0.8}

      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      mock_response = %{
        status: 200,
        body: %{
          "choices" => [%{"message" => %{"content" => "A red pixel"}}],
          "usage" => %{"prompt_tokens" => 100, "completion_tokens" => 5}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = Ollama.generate(model, prompt, config, documents: [document])
      assert response.content == "A red pixel"
    end

    test "returns zero cost for local model" do
      model = "llama3.2"
      prompt = "test"
      config = %{}

      mock_response = %{
        status: 200,
        body: %{
          "choices" => [%{"message" => %{"content" => "response"}}],
          "usage" => %{"prompt_tokens" => 1, "completion_tokens" => 1}
        }
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, response} = Ollama.generate(model, prompt, config, [])
      assert is_binary(response.content)
    end

    test "handles network errors" do
      model = "llama3.2"
      prompt = "test"
      config = %{}

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:error, :econnrefused}
      end)

      assert {:error, {:network_error, :econnrefused}} =
               Ollama.generate(model, prompt, config, [])
    end

    test "handles API errors" do
      model = "invalid-model"
      prompt = "test"
      config = %{}

      mock_response = %{
        status: 404,
        body: %{"error" => "model not found"}
      }

      expect(Aludel.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, mock_response}
      end)

      assert {:error, {:api_error, 404, _}} = Ollama.generate(model, prompt, config, [])
    end
  end
end
