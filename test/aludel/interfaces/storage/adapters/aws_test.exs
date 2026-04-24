defmodule Aludel.Interfaces.Storage.Adapters.AWSTest do
  use ExUnit.Case, async: true

  import Mox

  alias Aludel.Interfaces.Storage.Adapters.AWS
  alias Aludel.Interfaces.Storage.Adapters.AWS.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "put/4 delegates to the configured AWS client" do
    config = [bucket: "aludel-docs", client: ClientMock, region: "us-east-1"]

    expect(ClientMock, :put_object, fn "aludel-docs",
                                       "docs/sample.pdf",
                                       "body",
                                       "application/pdf",
                                       ^config ->
      {:ok, "docs/sample.pdf"}
    end)

    assert {:ok, "docs/sample.pdf"} =
             AWS.put("docs/sample.pdf", "body", "application/pdf", config)
  end

  test "get/2 delegates to the configured AWS client" do
    config = [bucket: "aludel-docs", client: ClientMock]

    expect(ClientMock, :get_object, fn "aludel-docs", "docs/sample.pdf", ^config ->
      {:ok, "body"}
    end)

    assert {:ok, "body"} = AWS.get("docs/sample.pdf", config)
  end

  test "delete/2 delegates to the configured AWS client" do
    config = [bucket: "aludel-docs", client: ClientMock]

    expect(ClientMock, :delete_object, fn "aludel-docs", "docs/sample.pdf", ^config ->
      :ok
    end)

    assert :ok = AWS.delete("docs/sample.pdf", config)
  end

  test "returns an error when bucket is missing" do
    assert {:error, :missing_bucket} = AWS.put("docs/sample.pdf", "body", "application/pdf", [])
    assert {:error, :missing_bucket} = AWS.get("docs/sample.pdf", [])
    assert {:error, :missing_bucket} = AWS.delete("docs/sample.pdf", [])
  end

  test "returns an error when bucket is empty" do
    config = [bucket: ""]

    assert {:error, :missing_bucket} =
             AWS.put("docs/sample.pdf", "body", "application/pdf", config)

    assert {:error, :missing_bucket} = AWS.get("docs/sample.pdf", config)
    assert {:error, :missing_bucket} = AWS.delete("docs/sample.pdf", config)
  end

  test "returns an error when bucket is not a binary" do
    config = [bucket: 123]

    assert {:error, :missing_bucket} =
             AWS.put("docs/sample.pdf", "body", "application/pdf", config)

    assert {:error, :missing_bucket} = AWS.get("docs/sample.pdf", config)
    assert {:error, :missing_bucket} = AWS.delete("docs/sample.pdf", config)
  end
end
