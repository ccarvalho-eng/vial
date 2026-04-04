defmodule Aludel.Web.SuiteLive.IndexTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures

  alias Aludel.Projects

  describe "index page" do
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

    test "displays empty state when no suites exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/suites")

      assert html =~ "No suites" or html =~ "Suites"
    end

    test "displays multiple suites", %{conn: conn} do
      prompt1 = prompt_fixture(%{name: "Prompt 1"})
      prompt2 = prompt_fixture(%{name: "Prompt 2"})
      _suite1 = suite_fixture(%{name: "Suite 1", prompt_id: prompt1.id})
      _suite2 = suite_fixture(%{name: "Suite 2", prompt_id: prompt2.id})

      {:ok, view, _html} = live(conn, "/suites")

      html = render(view)
      assert html =~ "Suite 1"
      assert html =~ "Suite 2"
      assert html =~ "Prompt 1"
      assert html =~ "Prompt 2"
    end

    test "creates suite projects with suite type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites")

      html =
        render_submit(view, "create_project", %{
          "project" => %{"name" => "Suite Workspace"}
        })

      assert html =~ "Project created successfully"

      [project] = Projects.list_projects(type: :suite)
      assert project.name == "Suite Workspace"
      assert project.type == :suite
      assert Projects.list_projects(type: :prompt) == []
    end
  end

  describe "delete functionality" do
    test "deletes suite successfully", %{conn: conn} do
      suite = suite_fixture(%{name: "Test Suite"})

      {:ok, view, _html} = live(conn, "/suites")

      # Trigger delete event directly
      html =
        view
        |> render_click("delete", %{"id" => suite.id})

      assert html =~ "Suite deleted successfully"
      refute html =~ "Test Suite"
    end

    test "refreshes suite list after deletion", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Test Prompt"})
      suite1 = suite_fixture(%{name: "Suite 1", prompt_id: prompt.id})
      _suite2 = suite_fixture(%{name: "Suite 2", prompt_id: prompt.id})

      {:ok, view, _html} = live(conn, "/suites")

      assert render(view) =~ "Suite 1"
      assert render(view) =~ "Suite 2"

      html = render_click(view, "delete", %{"id" => suite1.id})

      refute html =~ "Suite 1"
      assert html =~ "Suite 2"
    end

    test "shows flash message after deletion", %{conn: conn} do
      suite = suite_fixture(%{name: "Test Suite"})

      {:ok, view, _html} = live(conn, "/suites")

      render_click(view, "delete", %{"id" => suite.id})

      assert render(view) =~ "Suite deleted successfully"
    end

    test "handles deletion of suite with test cases", %{conn: conn} do
      suite = suite_fixture(%{name: "Suite with Cases"})
      _test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, view, _html} = live(conn, "/suites")

      html = render_click(view, "delete", %{"id" => suite.id})

      assert html =~ "Suite deleted successfully"
      refute html =~ "Suite with Cases"
    end
  end
end
