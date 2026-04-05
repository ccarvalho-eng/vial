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
    magic_bytes = :binary.part(data, 0, min(byte_size(data), 8))

    validate_content_type(content_type, magic_bytes, data)
  end

  defp validate_content_type("application/pdf", <<"%PDF", _::binary>>, _data), do: :ok

  defp validate_content_type(
         "image/png",
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>,
         _data
       ),
       do: :ok

  defp validate_content_type(ct, <<0xFF, 0xD8, 0xFF, _::binary>>, _data)
       when ct in ["image/jpeg", "image/jpg"],
       do: :ok

  defp validate_content_type("application/json", <<char, _::binary>>, data)
       when char in [?{, ?[, 32, 9, 10, 13] do
    validate_json(data)
  end

  defp validate_content_type(ct, _magic_bytes, data) when ct in ["text/csv", "text/plain"] do
    validate_utf8_text(data)
  end

  defp validate_content_type(claimed, _magic_bytes, _data) do
    {:error, "File content does not match type #{claimed}"}
  end

  defp validate_json(data) do
    case Jason.decode(data) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "Invalid JSON file"}
    end
  end

  defp validate_utf8_text(data) do
    if String.valid?(data) do
      :ok
    else
      {:error, "File is not valid UTF-8 text"}
    end
  end
end
