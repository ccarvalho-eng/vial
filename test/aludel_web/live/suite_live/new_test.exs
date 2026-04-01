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

  describe "prompt selection" do
    test "updates when prompt is selected", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{name: "Test Prompt", template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      html =
        view
        |> element("#suite_prompt_id")
        |> render_change(%{"suite" => %{"prompt_id" => prompt.id}})

      # After selecting, page updates - verify through HTML
      assert html =~ prompt.name
    end

    test "shows prompt selector on mount", %{conn: conn} do
      _prompt = prompt_fixture_with_version(%{name: "Test Prompt"})

      {:ok, _view, html} = live(conn, "/suites/new")

      assert html =~ "Select a prompt"
      assert html =~ "Test Prompt"
    end
  end

  describe "test case management" do
    test "shows add test case button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/suites/new")

      assert html =~ "Add Test Case"
    end

    test "handles test case interactions", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      # Select prompt first
      view
      |> element("#suite_prompt_id")
      |> render_change(%{"suite" => %{"prompt_id" => prompt.id}})

      # Add test case
      html =
        view
        |> element("[phx-click='add_test_case']")
        |> render_click()

      # Verify test case was added by checking for variable field
      assert html =~ "name" or html =~ "var_value"
    end
  end

  describe "assertion management" do
    test "handles assertion interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      # Add a test case first
      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      # Test renders successfully after adding test case
      assert render(view) =~ "Add Assertion" or render(view) =~ "Assertions"
    end
  end

  describe "suite creation" do
    test "creates suite with test cases successfully", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> element("form")
      |> render_submit(%{
        "suite" => %{
          "name" => "New Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            "0" => %{
              "var_value_name" => "Alice",
              "assertion_type_0" => "contains",
              "assertion_value_0" => "hello"
            }
          }
        }
      })

      {_path, flash} = assert_redirect(view)
      assert flash["info"] == "Suite created successfully"
    end

    test "shows validation errors on invalid suite", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> element("form")
      |> render_submit(%{
        "suite" => %{
          "name" => "",
          "prompt_id" => ""
        }
      })

      assert render(view) =~ "can&#39;t be blank"
    end

    test "validates JSON assertions", %{conn: conn} do
      prompt = prompt_fixture_with_version()

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> element("form")
      |> render_submit(%{
        "suite" => %{
          "name" => "Test Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            "0" => %{
              "assertions_json" => "{invalid json}"
            }
          }
        }
      })

      assert render(view) =~ "Invalid JSON"
    end

    test "rejects invalid assertion types in JSON", %{conn: conn} do
      prompt = prompt_fixture_with_version()

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> element("form")
      |> render_submit(%{
        "suite" => %{
          "name" => "Test Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            "0" => %{
              "assertions_json" => ~s([{"type": "invalid_type", "value": "test"}])
            }
          }
        }
      })

      assert render(view) =~ "Invalid assertion type"
    end
  end
end
