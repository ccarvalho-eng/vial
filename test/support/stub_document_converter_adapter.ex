defmodule Aludel.Test.StubDocumentConverterAdapter do
  @moduledoc """
  Stub adapter for testing document conversion without ImageMagick.
  """

  @behaviour Aludel.Interfaces.DocumentConverter.Behaviour

  @impl true
  def convert_pdf_to_png(pdf_data, _opts) do
    # Return a fake PNG with recognizable content
    png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
    fake_png_data = png_header <> "converted from: " <> pdf_data
    {:ok, fake_png_data}
  end
end
