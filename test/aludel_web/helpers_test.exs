defmodule Aludel.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias Aludel.Web.Helpers

  describe "provider_icon/1" do
    test "returns OpenAI icon path" do
      assert Helpers.provider_icon(:openai) == "/images/open-ai-icon.svg"
    end

    test "returns Anthropic icon path" do
      assert Helpers.provider_icon(:anthropic) == "/images/anthropic-icon.svg"
    end

    test "returns Ollama icon path" do
      assert Helpers.provider_icon(:ollama) == "/images/ollama-icon.svg"
    end

    test "returns nil for unknown provider" do
      assert Helpers.provider_icon(:unknown) == nil
    end

    test "accepts provider struct and extracts enum" do
      provider = %{provider: :openai}
      assert Helpers.provider_icon(provider) == "/images/open-ai-icon.svg"
    end

    test "returns nil for invalid input" do
      assert Helpers.provider_icon("invalid") == nil
      assert Helpers.provider_icon(123) == nil
    end
  end
end
