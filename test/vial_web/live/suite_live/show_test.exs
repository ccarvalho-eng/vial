defmodule Vial.Web.SuiteLive.ShowTest do
  use Vial.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Vial.EvalsFixtures
  import Vial.PromptsFixtures

  test "displays suite details", %{conn: conn} do
    prompt = prompt_fixture(%{name: "Test Prompt"})
    suite = suite_fixture(%{name: "Test Suite", prompt_id: prompt.id})

    {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

    assert render(view) =~ "Test Suite"
    assert render(view) =~ "Test Prompt"
  end

  test "lists test cases", %{conn: conn} do
    suite = suite_fixture()
    _test_case = test_case_fixture(%{suite_id: suite.id})

    {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

    assert has_element?(view, "#test-cases")
  end

  test "has run suite button", %{conn: conn} do
    suite = suite_fixture()

    {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

    assert has_element?(view, "#run-suite-btn")
  end
end
