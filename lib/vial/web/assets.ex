defmodule Vial.Web.Assets do
  @moduledoc """
  Serves pre-compiled static assets for Vial dashboard.
  """

  import Plug.Conn

  @priv_dir :code.priv_dir(:vial)

  def css(conn, %{"md5" => md5}) do
    serve_asset(conn, "css", md5, "text/css; charset=utf-8")
  end

  def js(conn, %{"md5" => md5}) do
    serve_asset(conn, "js", md5, "application/javascript; charset=utf-8")
  end

  def font(conn, %{"path" => path}) do
    serve_static(conn, Path.join("fonts", path), "font/woff2")
  end

  def icon(conn, %{"path" => path}) do
    serve_static(conn, Path.join("icons", path), "image/svg+xml")
  end

  defp serve_asset(conn, type, md5, content_type) do
    path = Path.join([@priv_dir, "static", "#{type}-#{md5}.#{type}"])

    case File.read(path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_resp(200, content)

      {:error, _} ->
        send_resp(conn, 404, "Not Found")
    end
  end

  defp serve_static(conn, path, content_type) do
    full_path = Path.join([@priv_dir, "static", path])

    case File.read(full_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000")
        |> send_resp(200, content)

      {:error, _} ->
        send_resp(conn, 404, "Not Found")
    end
  end
end
