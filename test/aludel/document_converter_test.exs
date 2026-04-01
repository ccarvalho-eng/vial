defmodule Aludel.DocumentConverterTest do
  use ExUnit.Case, async: true

  alias Aludel.DocumentConverter

  describe "pdf_to_image/1" do
    test "converts PDF to PNG using adapter" do
      pdf_doc = %{
        data: "%PDF-1.4\ntest content",
        content_type: "application/pdf"
      }

      assert {:ok, result} = DocumentConverter.pdf_to_image(pdf_doc)
      assert result.content_type == "image/png"
      assert is_binary(result.data)
      # Stub returns PNG header
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = result.data
    end

    test "returns image unchanged if already PNG" do
      image_doc = %{
        data: <<0x89, 0x50, 0x4E, 0x47, "PNG data">>,
        content_type: "image/png"
      }

      assert {:ok, ^image_doc} = DocumentConverter.pdf_to_image(image_doc)
    end

    test "returns image unchanged if already JPEG" do
      jpeg_doc = %{
        data: <<0xFF, 0xD8, 0xFF, "JPEG data">>,
        content_type: "image/jpeg"
      }

      assert {:ok, ^jpeg_doc} = DocumentConverter.pdf_to_image(jpeg_doc)
    end

    test "returns text unchanged if not PDF" do
      text_doc = %{
        data: "some text content",
        content_type: "text/plain"
      }

      assert {:ok, ^text_doc} = DocumentConverter.pdf_to_image(text_doc)
    end

    test "returns JSON unchanged if not PDF" do
      json_doc = %{
        data: ~s({"key": "value"}),
        content_type: "application/json"
      }

      assert {:ok, ^json_doc} = DocumentConverter.pdf_to_image(json_doc)
    end
  end
end
