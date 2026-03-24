defmodule Vial.Web.AssetsTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Vial.Web.Assets

  describe "css/2" do
    test "returns 404 when asset not found" do
      conn =
        conn(:get, "/assets/css-abc123.css")
        |> Assets.css(%{"md5" => "abc123"})

      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end
  end

  describe "js/2" do
    test "returns 404 when asset not found" do
      conn =
        conn(:get, "/assets/js-abc123.js")
        |> Assets.js(%{"md5" => "abc123"})

      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end
  end

  describe "font/2" do
    test "returns 404 when font not found" do
      conn =
        conn(:get, "/assets/fonts/Inter.woff2")
        |> Assets.font(%{"path" => "Inter.woff2"})

      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end
  end

  describe "icon/2" do
    test "returns 404 when icon not found" do
      conn =
        conn(:get, "/assets/icons/outline/check.svg")
        |> Assets.icon(%{"path" => "outline/check.svg"})

      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end
  end
end
