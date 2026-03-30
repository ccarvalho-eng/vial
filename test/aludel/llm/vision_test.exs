defmodule Aludel.LLM.VisionTest do
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

  describe "call/3 with OpenAI vision models" do
    test "processes image with gpt-4o" do
      mock_response = build_mock_response("The image is red", 100, 20)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{"temperature" => 0.7, "max_tokens" => 500}
        })

      # Sample 1x1 red PNG
      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      assert {:ok, result} =
               LLM.call(provider, "What color is this image?", documents: [document])

      assert is_binary(result.output)
      assert result.output != ""
      assert result.input_tokens > 0
      assert result.output_tokens > 0
      assert is_float(result.cost_usd)
      assert result.cost_usd > 0
    end

    test "processes multiple images" do
      mock_response = build_mock_response("Both images are different colors", 150, 25)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o-mini",
          config: %{"max_tokens" => 300}
        })

      red_pixel =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      blue_pixel =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mJw/c/wHwAF2gJ1KxURKwAAAABJRU5ErkJggg=="
        )

      documents = [
        %{data: red_pixel, content_type: "image/png"},
        %{data: blue_pixel, content_type: "image/png"}
      ]

      assert {:ok, result} =
               LLM.call(provider, "Compare these images", documents: documents)

      assert is_binary(result.output)
      assert result.output != ""
      assert result.input_tokens > 0
      assert result.output_tokens > 0
    end

    test "returns error when non-vision model used with documents" do
      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:error, %{status: 400}}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-3.5-turbo",
          config: %{}
        })

      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      result = LLM.call(provider, "Describe this image", documents: [document])

      assert {:error, {:invalid_request, _}} = result
    end

    test "works without documents for text-only prompts" do
      mock_response = build_mock_response("Hello!", 5, 2)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "Say hello")

      assert {:ok, _} = result
    end
  end

  describe "Anthropic vision" do
    test "processes image with claude-3-5-sonnet" do
      mock_response = build_mock_response("This is a red pixel image", 120, 18)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet",
          config: %{"max_tokens" => 500}
        })

      # Sample 1x1 red PNG
      image_data =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      document = %{data: image_data, content_type: "image/png"}

      assert {:ok, result} =
               LLM.call(provider, "What color is this image?", documents: [document])

      assert is_binary(result.output)
      assert result.output != ""
      assert result.input_tokens > 0
      assert result.output_tokens > 0
      assert is_float(result.cost_usd)
      assert result.cost_usd > 0
    end

    test "processes multiple images" do
      mock_response = build_mock_response("Different colored pixels", 140, 22)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-haiku",
          config: %{"max_tokens" => 300}
        })

      red_pixel =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        )

      blue_pixel =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mJw/c/wHwAF2gJ1KxURKwAAAABJRU5ErkJggg=="
        )

      documents = [
        %{data: red_pixel, content_type: "image/png"},
        %{data: blue_pixel, content_type: "image/png"}
      ]

      assert {:ok, result} =
               LLM.call(provider, "Compare these images", documents: documents)

      assert is_binary(result.output)
      assert result.output != ""
      assert result.input_tokens > 0
      assert result.output_tokens > 0
    end

    test "works without documents for text-only prompts" do
      mock_response = build_mock_response("Hello there!", 6, 3)

      expect(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      provider =
        provider_fixture(%{
          provider: :anthropic,
          model: "claude-3-5-sonnet",
          config: %{}
        })

      result = LLM.call(provider, "Say hello")

      assert {:ok, _} = result
    end
  end
end
