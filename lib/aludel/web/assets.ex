defmodule Aludel.Web.Assets do
  @moduledoc """
  Serves pre-compiled static assets for Aludel dashboard.

  Assets are read at compile time and hashes are calculated dynamically
  from the file contents for cache busting.
  """

  @behaviour Plug

  import Plug.Conn

  # In development/test, read from project root dist/
  # In production (as a dep), read from the package's dist/
  @dist_path (if Mix.env() in [:dev, :test] do
                Path.join(File.cwd!(), "dist")
              else
                Application.app_dir(:aludel, ["dist"])
              end)

  # CSS
  @external_resource css_path = Path.join(@dist_path, "app.css")
  @css File.read!(css_path)

  # JS
  @external_resource js_path = Path.join(@dist_path, "app.js")
  @js File.read!(js_path)

  # Generate current_hash/1 functions with MD5 hashes
  for {key, val} <- [css: @css, js: @js] do
    md5 = Base.encode16(:crypto.hash(:md5, val), case: :lower) |> String.slice(0, 8)

    def current_hash(unquote(key)), do: unquote(md5)
  end

  @impl Plug
  def init(asset), do: asset

  @impl Plug
  def call(conn, :css) do
    %{"md5" => md5} = conn.params
    serve_asset(conn, :css, md5, @css, "text/css; charset=utf-8")
  end

  def call(conn, :js) do
    %{"md5" => md5} = conn.params
    serve_asset(conn, :js, md5, @js, "application/javascript; charset=utf-8")
  end

  def call(conn, :font) do
    %{"path" => path} = conn.params
    serve_static(conn, Path.join(["fonts" | normalize_path(path)]), "font/woff2")
  end

  def call(conn, :icon) do
    %{"path" => path} = conn.params
    serve_static(conn, Path.join(["icons" | normalize_path(path)]), "image/svg+xml")
  end

  def call(conn, :image) do
    %{"path" => path} = conn.params
    serve_static(conn, Path.join(["images" | normalize_path(path)]), "image/svg+xml")
  end

  defp serve_asset(conn, type, requested_md5, content, content_type) do
    # Validate hash matches to prevent cache poisoning
    if valid_md5?(requested_md5) and requested_md5 == current_hash(type) do
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> put_private(:plug_skip_csrf_protection, true)
      |> send_resp(200, content)
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  defp serve_static(conn, path, content_type) do
    priv_dir = :code.priv_dir(:aludel)
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

  # Normalize path parameter - Phoenix wildcard routes (*path) return lists
  defp normalize_path(path) when is_list(path), do: path
  defp normalize_path(path) when is_binary(path), do: [path]
end
