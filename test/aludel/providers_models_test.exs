defmodule Aludel.ProvidersModelsTest do
  use ExUnit.Case, async: true

  alias Aludel.Providers

  describe "fetch_models/1" do
    test "returns models for openai" do
      models = Providers.fetch_models(:openai)
      assert is_list(models)
      # Check if some common OpenAI models are in the list if they are not deprecated
      # This depends on what LlmDb returns, but it should be a list of maps with :id and :name
      if models != [] do
        Enum.each(models, fn m ->
          assert Map.has_key?(m, :id)
          assert Map.has_key?(m, :name)
        end)
      end
    end

    test "returns models sorted by name" do
      models = Providers.fetch_models(:openai)

      assert Enum.sort_by(models, fn %{name: name, id: id} ->
               {String.downcase(name), String.downcase(id)}
             end) == models
    end

    test "returns models for anthropic" do
      models = Providers.fetch_models(:anthropic)
      assert is_list(models)
    end

    test "returns models for ollama" do
      models = Providers.fetch_models(:ollama)
      assert is_list(models)
    end

    test "returns empty list for invalid provider" do
      assert Providers.fetch_models(:invalid) == []
    end

    test "returns empty list for nil or empty string" do
      assert Providers.fetch_models(nil) == []
      assert Providers.fetch_models("") == []
    end
  end
end
