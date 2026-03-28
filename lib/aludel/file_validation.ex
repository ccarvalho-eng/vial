defmodule Aludel.FileValidation do
  @moduledoc """
  Validates file content against claimed MIME types using magic bytes.

  Prevents file type spoofing by checking actual file signatures instead of
  relying solely on file extensions or Content-Type headers.
  """

  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Validates that file content matches the claimed MIME type.

  Uses magic bytes (file signatures) to verify the actual file format.
  Supported types: PDF, PNG, JPEG, JSON, CSV, TXT.

  ## Examples

      iex> pdf_data = "%PDF-1.4..."
      iex> FileValidation.validate(pdf_data, "application/pdf")
      :ok

      iex> text_data = "not a pdf"
      iex> FileValidation.validate(text_data, "application/pdf")
      {:error, "File content does not match type application/pdf"}
  """
  @spec validate(binary(), String.t()) :: validation_result()
  def validate(data, content_type) do
    # Check magic bytes (file signatures) for common types
    magic_bytes = :binary.part(data, 0, min(byte_size(data), 8))

    case {content_type, magic_bytes} do
      # PDF files start with %PDF
      {"application/pdf", <<"%PDF", _::binary>>} ->
        :ok

      # PNG files
      {"image/png", <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>} ->
        :ok

      # JPEG files (accept common MIME variants)
      {ct, <<0xFF, 0xD8, 0xFF, _::binary>>} when ct in ["image/jpeg", "image/jpg"] ->
        :ok

      # JSON (starts with { or [)
      {"application/json", <<char, _::binary>>} when char in [?{, ?[, 32, 9, 10, 13] ->
        # Validate it's actually valid JSON
        case Jason.decode(data) do
          {:ok, _} -> :ok
          {:error, _} -> {:error, "Invalid JSON file"}
        end

      # CSV and TXT - allow any text content (no reliable magic bytes)
      {ct, _} when ct in ["text/csv", "text/plain"] ->
        # Just verify it's valid UTF-8
        if String.valid?(data) do
          :ok
        else
          {:error, "File is not valid UTF-8 text"}
        end

      # Mismatch between claimed type and actual content
      {claimed, _} ->
        {:error, "File content does not match type #{claimed}"}
    end
  end
end
