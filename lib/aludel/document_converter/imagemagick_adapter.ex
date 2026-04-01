defmodule Aludel.DocumentConverter.ImagemagickAdapter do
  @moduledoc """
  ImageMagick adapter for document conversion.

  Requires ImageMagick v7+ to be installed on the system.
  """

  @behaviour Aludel.DocumentConverter.Adapter

  require Logger

  @impl true
  def convert_pdf_to_png(pdf_data, opts \\ []) do
    density = Keyword.get(opts, :density, 150)
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    pdf_path = System.tmp_dir!() |> Path.join("aludel_pdf_#{unique_id}.pdf")
    png_path = System.tmp_dir!() |> Path.join("aludel_png_#{unique_id}.png")

    try do
      File.write!(pdf_path, pdf_data)

      case System.cmd(
             "magick",
             [
               "-density",
               to_string(density),
               pdf_path <> "[0]",
               "-flatten",
               png_path
             ],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          png_data = File.read!(png_path)
          {:ok, png_data}

        {error_output, exit_code} ->
          Logger.error("ImageMagick conversion failed with code #{exit_code}: #{error_output}")

          {:error, {:conversion_failed, exit_code, error_output}}
      end
    catch
      kind, reason ->
        Logger.error("Document conversion crashed: #{inspect(kind)} - #{inspect(reason)}")

        {:error, {:conversion_crashed, kind, reason}}
    after
      cleanup_temp_file(pdf_path)
      cleanup_temp_file(png_path)
    end
  end

  defp cleanup_temp_file(path) do
    case File.rm(path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete temp file #{path}: #{inspect(reason)}")
    end
  end
end
