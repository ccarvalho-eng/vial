defmodule Aludel.Interfaces.Storage.Adapters.GCSTest do
  use ExUnit.Case, async: true

  import Mox

  alias Aludel.Interfaces.Storage.Adapters.GCS
  alias Aludel.Interfaces.Storage.Adapters.GCS.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "put/4 delegates to the configured GCS client" do
    config = [bucket: "aludel-docs", client: ClientMock, goth: :aludel_goth]

    expect(ClientMock, :put_object, fn "aludel-docs",
                                       "docs/sample.pdf",
                                       "body",
                                       "application/pdf",
                                       ^config ->
      {:ok, "docs/sample.pdf"}
    end)

    assert {:ok, "docs/sample.pdf"} =
             GCS.put("docs/sample.pdf", "body", "application/pdf", config)
  end

  test "get/2 delegates to the configured GCS client" do
    config = [bucket: "aludel-docs", client: ClientMock]

    expect(ClientMock, :get_object, fn "aludel-docs", "docs/sample.pdf", ^config ->
      {:ok, "body"}
    end)

    assert {:ok, "body"} = GCS.get("docs/sample.pdf", config)
  end

  test "delete/2 delegates to the configured GCS client" do
    config = [bucket: "aludel-docs", client: ClientMock]

    expect(ClientMock, :delete_object, fn "aludel-docs", "docs/sample.pdf", ^config ->
      :ok
    end)

    assert :ok = GCS.delete("docs/sample.pdf", config)
  end

  test "returns an error when bucket is missing" do
    assert {:error, :missing_bucket} = GCS.put("docs/sample.pdf", "body", "application/pdf", [])
    assert {:error, :missing_bucket} = GCS.get("docs/sample.pdf", [])
    assert {:error, :missing_bucket} = GCS.delete("docs/sample.pdf", [])
  end
end
