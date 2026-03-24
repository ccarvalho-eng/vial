defmodule Vial.Web.CacheTest do
  use ExUnit.Case, async: false

  alias Vial.Web.Cache

  setup do
    start_supervised!(Cache)
    :ok
  end

  describe "get/1 and put/3" do
    test "stores and retrieves values" do
      key = :test_key
      value = %{data: "test"}

      assert Cache.put(key, value, 60) == :ok
      assert Cache.get(key) == {:ok, value}
    end

    test "returns error for missing keys" do
      assert Cache.get(:nonexistent) == :error
    end

    test "returns error for expired keys" do
      Cache.put(:key, "value", 0)
      Process.sleep(10)
      assert Cache.get(:key) == :error
    end
  end
end
