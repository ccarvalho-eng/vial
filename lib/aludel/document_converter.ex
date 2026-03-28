defmodule Aludel.DocumentConverter do
  @moduledoc """
  Converts documents between formats for LLM consumption.

  Currently supports:
  - PDF → PNG (first page only, 150 DPI)

  ## Requirements

  Requires ImageMagick v7+ to be installed:
  - macOS: `brew install imagemagick`
  - Ubuntu/Debian: `apt-get install imagemagick`
  - Docker: Install in runtime image
  """

  require Logger

  @type document :: %{data: binary(), content_type: String.t()}
  @type convert_result :: {:ok, document()} | {:error, term()}

  @doc """
  Converts a PDF document to PNG format.

  Only converts the first page at 150 DPI for optimal text readability.
  Creates temporary files for conversion and cleans them up afterwards.

  ## Examples

      iex> pdf_doc = %{data: pdf_binary, content_type: "application/pdf"}
      iex> {:ok, png_doc} = DocumentConverter.pdf_to_image(pdf_doc)
      iex> png_doc.content_type
      "image/png"

      iex> image_doc = %{data: png_binary, content_type: "image/png"}
      iex> {:ok, ^image_doc} = DocumentConverter.pdf_to_image(image_doc)
      :ok
  """
  @spec pdf_to_image(document()) :: convert_result()
  def pdf_to_image(%{content_type: "application/pdf", data: pdf_data}) do
    # Create temp files for PDF and PNG conversion with unique IDs
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    pdf_path = System.tmp_dir!() |> Path.join("aludel_pdf_#{unique_id}.pdf")
    png_path = System.tmp_dir!() |> Path.join("aludel_png_#{unique_id}.png")

    try do
      # Write PDF to temp file
      File.write!(pdf_path, pdf_data)

      # Convert PDF to PNG using ImageMagick
      # -density 150: good quality for text
      # -flatten: merge layers
      # [0]: only first page
      case System.cmd(
             "magick",
             [
               "-density",
               "150",
               pdf_path <> "[0]",
               "-flatten",
               png_path
             ],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          # Read converted PNG
          png_data = File.read!(png_path)
          {:ok, %{data: png_data, content_type: "image/png"}}

        {error_output, exit_code} ->
          Logger.error("ImageMagick conversion failed with code #{exit_code}: #{error_output}")
          {:error, {:conversion_failed, exit_code, error_output}}
      end
    catch
      kind, reason ->
        Logger.error("Document conversion crashed: #{inspect(kind)} - #{inspect(reason)}")
        {:error, {:conversion_crashed, kind, reason}}
    after
      # Clean up temp files and log any cleanup failures
      case File.rm(pdf_path) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to delete temp PDF file #{pdf_path}: #{inspect(reason)}")
      end

      case File.rm(png_path) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to delete temp PNG file #{png_path}: #{inspect(reason)}")
      end
    end
  end

  def pdf_to_image(doc), do: {:ok, doc}
end
