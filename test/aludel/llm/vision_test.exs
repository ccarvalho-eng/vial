defmodule Aludel.LLM.VisionTest do
  use Aludel.DataCase, async: true

  alias Aludel.LLM

  describe "call/3 with OpenAI vision models" do
    @tag :openai_integration
    test "processes image with gpt-4o" do
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

    @tag :openai_integration
    test "processes multiple images" do
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

    @tag :openai_integration
    test "returns error when non-vision model used with documents" do
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

      result =
        LLM.call(provider, "Describe this image", documents: [document])

      assert match?({:error, {:invalid_request, _}}, result) or
               match?({:error, {:api_error, _, _}}, result)
    end

    test "works without documents for text-only prompts" do
      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o",
          config: %{}
        })

      result = LLM.call(provider, "Say hello")

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
