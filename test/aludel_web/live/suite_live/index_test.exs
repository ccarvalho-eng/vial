defmodule Aludel.Web.SuiteLive.IndexTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures

  test "renders list of suites", %{conn: conn} do
    prompt = prompt_fixture(%{name: "Test Prompt"})
    _suite = suite_fixture(%{name: "Test Suite", prompt_id: prompt.id})

    {:ok, view, _html} = live(conn, "/suites")

    assert has_element?(view, "table")
    assert render(view) =~ "Test Suite"
    assert render(view) =~ "Test Prompt"
  end

  test "links to suite show page", %{conn: conn} do
    suite = suite_fixture(%{name: "Test Suite"})

    {:ok, view, _html} = live(conn, "/suites")

    assert has_element?(view, "a[href='/suites/#{suite.id}']")
  end

  test "has button to create new suite", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/suites")

    assert has_element?(view, "#new-suite-btn")
  end
end
