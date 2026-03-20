defmodule VialWeb.SuiteLive.IndexTest do
  use VialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Vial.EvalsFixtures
  import Vial.PromptsFixtures

  test "renders list of suites", %{conn: conn} do
    prompt = prompt_fixture(%{name: "Test Prompt"})
    _suite = suite_fixture(%{name: "Test Suite", prompt_id: prompt.id})

    {:ok, view, _html} = live(conn, ~p"/suites")

    assert has_element?(view, "#suites")
    assert render(view) =~ "Test Suite"
    assert render(view) =~ "Test Prompt"
  end

  test "links to suite show page", %{conn: conn} do
    suite = suite_fixture(%{name: "Test Suite"})

    {:ok, view, _html} = live(conn, ~p"/suites")

    assert has_element?(view, "a[href='/suites/#{suite.id}']")
  end

  test "has button to create new suite", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/suites")

    assert has_element?(view, "#new-suite-btn")
  end
end
