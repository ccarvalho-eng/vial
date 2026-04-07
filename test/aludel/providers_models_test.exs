defmodule Aludel.ProvidersModelsTest do
  use ExUnit.Case, async: true

  alias Aludel.Providers

  describe "group_models/1" do
    test "splits active and deprecated models and sorts each group" do
      models = [
        %{id: "b-active", name: "Beta", deprecated: false},
        %{id: "a-deprecated", name: "Alpha", deprecated: true},
        %{id: "a-active", name: "Alpha", deprecated: false}
      ]

      assert %{active: active, deprecated: deprecated} = Providers.group_models(models)
      assert Enum.map(active, & &1.id) == ["a-active", "b-active"]
      assert Enum.map(deprecated, & &1.id) == ["a-deprecated"]
    end
  end

  describe "fetch_models/1" do
    test "returns active models only" do
      models = Providers.fetch_models(:openai)
      assert is_list(models)

      Enum.each(models, fn model ->
        assert Map.has_key?(model, :id)
        assert Map.has_key?(model, :name)
      end)
    end

    test "returns empty list for invalid provider" do
      assert Providers.fetch_models(:invalid) == []
    end
  end

  describe "fetch_model_groups/1" do
    test "returns active and deprecated groups" do
      groups = Providers.fetch_model_groups(:openai)

      assert Map.has_key?(groups, :active)
      assert Map.has_key?(groups, :deprecated)
      assert is_list(groups.active)
      assert is_list(groups.deprecated)
    end
  end
end
