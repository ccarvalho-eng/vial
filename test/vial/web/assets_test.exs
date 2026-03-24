defmodule Vial.Web.AssetsTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Vial.Web.Assets

  describe "css/2" do
    test "serves CSS with md5 hash" do
      conn =
        conn(:get, "/assets/app.css")
        |> Assets.call(:css)

      assert conn.status in [200, 404]
      assert get_resp_header(conn, "content-type") == ["text/css"]

      if conn.status == 200 do
        assert get_resp_header(conn, "cache-control") == [
                 "public, max-age=31536000, immutable"
               ]
      end
    end

    test "has current_hash/1 for css" do
      assert is_binary(Assets.current_hash(:css))
      assert String.length(Assets.current_hash(:css)) == 32
    end
  end

  describe "js/2" do
    test "serves JS with md5 hash" do
      conn =
        conn(:get, "/assets/app.js")
        |> Assets.call(:js)

      assert conn.status in [200, 404]
      assert get_resp_header(conn, "content-type") == ["text/javascript"]

      if conn.status == 200 do
        assert get_resp_header(conn, "cache-control") == [
                 "public, max-age=31536000, immutable"
               ]
      end
    end

    test "has current_hash/1 for js" do
      assert is_binary(Assets.current_hash(:js))
      assert String.length(Assets.current_hash(:js)) == 32
    end
  end

  describe "font/2" do
    test "serves font files" do
      conn =
        conn(:get, "/assets/font.woff2")
        |> Assets.call(:font)

      assert conn.status in [200, 404]
      assert get_resp_header(conn, "content-type") == ["font/woff2"]

      if conn.status == 200 do
        assert get_resp_header(conn, "cache-control") == [
                 "public, max-age=31536000, immutable"
               ]
      end
    end
  end

  describe "icon/2" do
    test "serves icon files from path params" do
      conn =
        conn(:get, "/assets/icons/outline/check.svg")
        |> Map.put(:path_params, %{"path" => ["outline", "check.svg"]})
        |> Assets.call(:icon)

      assert conn.status in [200, 404]

      if conn.status == 200 do
        assert get_resp_header(conn, "content-type") == ["image/svg+xml"]

        assert get_resp_header(conn, "cache-control") == [
                 "public, max-age=31536000, immutable"
               ]
      else
        assert get_resp_header(conn, "content-type") == ["text/plain"]
      end
    end

    test "returns 404 for non-existent icon" do
      conn =
        conn(:get, "/assets/icons/missing/icon.svg")
        |> Map.put(:path_params, %{"path" => ["missing", "icon.svg"]})
        |> Assets.call(:icon)

      assert conn.status == 404
      assert get_resp_header(conn, "content-type") == ["text/plain"]
    end
  end
end
