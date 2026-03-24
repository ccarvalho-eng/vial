defmodule Vial.Static do
  @moduledoc """
  Plug for serving pre-compiled Vial assets from the package.

  This module handles serving CSS, JS, and other static assets that have been
  pre-compiled and bundled with the Vial hex package. It's used internally by
  the Vial.Router macro to serve assets without requiring the host application
  to manage them.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{path_info: ["vial-assets" | path]} = conn, _opts) do
    serve_static(conn, path)
  end

  def call(conn, _opts), do: conn

  defp serve_static(conn, path) do
    file_path = Path.join(path)

    # Security: Prevent directory traversal
    if String.contains?(file_path, "..") do
      send_resp(conn, 404, "Not found")
    else
      serve_file(conn, file_path)
    end
  end

  defp serve_file(conn, file_path) do
    # Determine the full path within the priv/static/vial directory
    app_dir = :code.priv_dir(:vial)
    full_path = Path.join([app_dir, "static", "vial", file_path])

    if File.exists?(full_path) do
      # Determine content type based on file extension
      content_type = get_content_type(file_path)

      # Read and serve the file
      {:ok, content} = File.read(full_path)

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_resp(200, content)
      |> halt()
    else
      conn
      |> send_resp(404, "Not found")
      |> halt()
    end
  end

  defp get_content_type(path) do
    case Path.extname(path) do
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".json" -> "application/json"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      ".woff" -> "font/woff"
      ".woff2" -> "font/woff2"
      ".ttf" -> "font/ttf"
      ".eot" -> "application/vnd.ms-fontobject"
      _ -> "application/octet-stream"
    end
  end
end
