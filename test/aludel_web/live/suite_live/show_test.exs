defmodule Aludel.Web.SuiteLive.ShowTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures

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

  describe "visual test case display" do
    test "displays variables in readable format", %{conn: conn} do
      suite = suite_fixture()

      _test_case =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"name" => "Alice", "age" => "30"}
        })

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      html = render(view)
      assert html =~ "name"
      assert html =~ "Alice"
      assert html =~ "age"
      assert html =~ "30"
      refute html =~ "inspect("
    end

    test "displays empty state when no variables", %{conn: conn} do
      suite = suite_fixture()
      _test_case = test_case_fixture(%{suite_id: suite.id, variable_values: %{}})

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      assert render(view) =~ "No variables"
    end

    test "displays assertions in readable format", %{conn: conn} do
      suite = suite_fixture()

      _test_case =
        test_case_fixture(%{
          suite_id: suite.id,
          assertions: [
            %{"type" => "contains", "value" => "hello"},
            %{"type" => "regex", "value" => "world.*"}
          ]
        })

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      html = render(view)
      assert html =~ "contains"
      assert html =~ "hello"
      assert html =~ "regex"
      assert html =~ "world.*"
      refute html =~ "%{\"type\""
    end

    test "displays document attachments", %{conn: conn} do
      suite = suite_fixture()
      test_case = test_case_fixture(%{suite_id: suite.id})

      _document =
        test_case_document_fixture(%{
          test_case_id: test_case.id,
          filename: "test.pdf",
          content_type: "application/pdf",
          size_bytes: 1024
        })

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      html = render(view)
      assert html =~ "test.pdf"
      assert html =~ "1024"
    end

    test "displays empty state when no documents", %{conn: conn} do
      suite = suite_fixture()
      _test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      assert render(view) =~ "No documents"
    end

    test "has edit button for each test case", %{conn: conn} do
      suite = suite_fixture()
      test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      assert has_element?(view, "[phx-click='edit_test_case'][phx-value-id='#{test_case.id}']")
    end

    test "has delete button for each test case", %{conn: conn} do
      suite = suite_fixture()
      test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, view, _html} = live(conn, "/suites/#{suite.id}")

      # Delete button now opens a confirmation modal
      assert has_element?(view, "button", "Delete")
      assert has_element?(view, "#confirm-delete-test-case-#{test_case.id}")
    end
  end
end
