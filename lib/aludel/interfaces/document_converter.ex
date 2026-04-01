defmodule Aludel.DocumentConverter do
  @moduledoc """
  Converts documents between formats for LLM consumption.

  Currently supports:
  - PDF → PNG (first page only, 150 DPI)

  ## Usage

  PDF-to-image conversion is only used for:
  - **Ollama**: Vision models require image formats

  Modern LLM providers accept PDFs natively:
  - **Anthropic Claude 4.5+**: Supports PDFs via document API
  - **OpenAI**: Accepts PDFs directly via file input API

  ## Requirements

  Requires ImageMagick v7+ to be installed (only needed for Ollama):
  - macOS: `brew install imagemagick`
  - Ubuntu/Debian: `apt-get install imagemagick`
  - Docker: Install in runtime image

  ## Configuration

  The conversion adapter can be configured in config files:

      config :aludel, :document_converter,
        adapter: Aludel.Interfaces.DocumentConverter.Adapters.Imagemagick

  For testing, use a stub adapter.
  """

  @type document :: %{data: binary(), content_type: String.t()}
  @type convert_result :: {:ok, document()} | {:error, term()}

  @default_adapter Aludel.Interfaces.DocumentConverter.Adapters.Imagemagick

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
    case adapter().convert_pdf_to_png(pdf_data, []) do
      {:ok, png_data} ->
        {:ok, %{data: png_data, content_type: "image/png"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def pdf_to_image(doc), do: {:ok, doc}

  defp adapter do
    case Application.get_env(:aludel, :document_converter, []) do
      adapter when is_atom(adapter) and not is_nil(adapter) ->
        adapter

      config when is_list(config) ->
        Keyword.get(config, :adapter, @default_adapter)

      _ ->
        @default_adapter
    end
  end
end
