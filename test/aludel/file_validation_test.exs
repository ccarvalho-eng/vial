defmodule Aludel.FileValidationTest do
  use ExUnit.Case, async: true

  alias Aludel.FileValidation

  describe "validate/2" do
    test "validates PDF files" do
      pdf_data = "%PDF-1.4\nsome content"
      assert :ok = FileValidation.validate(pdf_data, "application/pdf")
    end

    test "rejects invalid PDF files" do
      invalid_data = "not a pdf"

      assert {:error, msg} =
               FileValidation.validate(invalid_data, "application/pdf")

      assert msg =~ "does not match type"
    end

    test "validates PNG files" do
      # PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
      png_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "data">>
      assert :ok = FileValidation.validate(png_data, "image/png")
    end

    test "validates JPEG files" do
      # JPEG magic bytes: FF D8 FF
      jpeg_data = <<0xFF, 0xD8, 0xFF, 0xE0, "data">>
      assert :ok = FileValidation.validate(jpeg_data, "image/jpeg")
      assert :ok = FileValidation.validate(jpeg_data, "image/jpg")
    end

    test "validates JSON files" do
      json_data = ~s({"key": "value"})
      assert :ok = FileValidation.validate(json_data, "application/json")
    end

    test "rejects invalid JSON" do
      invalid_json = "{not valid json"

      assert {:error, msg} =
               FileValidation.validate(invalid_json, "application/json")

      assert msg =~ "Invalid JSON"
    end

    test "validates CSV files" do
      csv_data = "name,age\nAlice,30"
      assert :ok = FileValidation.validate(csv_data, "text/csv")
    end

    test "validates plain text files" do
      text_data = "Hello, world!"
      assert :ok = FileValidation.validate(text_data, "text/plain")
    end

    test "rejects non-UTF8 text" do
      invalid_utf8 = <<0xFF, 0xFE, 0xFD>>

      assert {:error, msg} =
               FileValidation.validate(invalid_utf8, "text/plain")

      assert msg =~ "not valid UTF-8"
    end

    test "rejects type mismatches" do
      pdf_data = "%PDF-1.4"

      assert {:error, msg} =
               FileValidation.validate(pdf_data, "image/png")

      assert msg =~ "does not match type image/png"
    end
  end
end
