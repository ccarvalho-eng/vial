defmodule Vial.Web.Assets do
  @moduledoc """
  Serves pre-compiled static assets for Vial dashboard.
  """

  @behaviour Plug

  import Plug.Conn

  @css_hash "9561d988"
  @js_hash "4a88baa4"

  def current_hash(:css), do: @css_hash
  def current_hash(:js), do: @js_hash

  @impl Plug
  def init(asset), do: asset

  @impl Plug
  def call(conn, :css) do
    %{"md5" => md5} = conn.params
    serve_asset(conn, "css", md5, "text/css; charset=utf-8")
  end

  def call(conn, :js) do
    %{"md5" => md5} = conn.params
    serve_asset(conn, "js", md5, "application/javascript; charset=utf-8")
  end

  def call(conn, :font) do
    %{"path" => path} = conn.params
    serve_static(conn, Path.join("fonts", path), "font/woff2")
  end

  def call(conn, :icon) do
    %{"path" => path} = conn.params
    serve_static(conn, Path.join("icons", path), "image/svg+xml")
  end

  # Legacy function-based endpoints (for backwards compatibility)
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
    # Validate md5 hash to prevent path traversal
    if valid_md5?(md5) do
      priv_dir = :code.priv_dir(:vial)
      path = Path.join([priv_dir, "static", "#{type}-#{md5}.#{type}"])

      case File.read(path) do
        {:ok, content} ->
          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
          |> put_private(:plug_skip_csrf_protection, true)
          |> send_resp(200, content)

        {:error, _} ->
          send_resp(conn, 404, "Not Found")
      end
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  defp serve_static(conn, path, content_type) do
    priv_dir = :code.priv_dir(:vial)
    full_path = Path.join([priv_dir, "static", path])

    # Prevent path traversal by ensuring resolved path is within static dir
    static_dir = Path.join(priv_dir, "static")

    with {:ok, resolved} <- resolve_path(full_path),
         true <- String.starts_with?(resolved, static_dir) do
      case File.read(resolved) do
        {:ok, content} ->
          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("cache-control", "public, max-age=31536000")
          |> put_private(:plug_skip_csrf_protection, true)
          |> send_resp(200, content)

        {:error, _} ->
          send_resp(conn, 404, "Not Found")
      end
    else
      _ -> send_resp(conn, 404, "Not Found")
    end
  end

  defp resolve_path(path) do
    case File.stat(path) do
      {:ok, _} -> {:ok, Path.expand(path)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp valid_md5?(md5) when is_binary(md5) do
    String.match?(md5, ~r/^[a-f0-9]{8}$/)
  end

  defp valid_md5?(_), do: false
end
