defmodule Aludel.Web.SuiteLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  describe "new suite page" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/suites/new")

      assert html =~ "New Suite"
    end

    test "displays prompt selector", %{conn: conn} do
      _prompt = prompt_fixture(%{name: "Test Prompt"})

      {:ok, _view, html} = live(conn, "/suites/new")

      assert html =~ "Test Prompt"
    end

    test "shows add test case button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/suites/new")

      assert html =~ "Add Test Case"
    end
  end
end
