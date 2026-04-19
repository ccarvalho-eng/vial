defmodule Aludel.Web.SuiteLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  alias Aludel.Projects

  describe "new suite page" do
    test "mounts successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(view, "#suite-form")
    end

    test "displays prompt selector", %{conn: conn} do
      _prompt = prompt_fixture(%{name: "Test Prompt"})

      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(view, "#suite_prompt_id-select [data-select-option]", "Test Prompt")
    end

    test "shows add test case button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(view, "button[phx-click='add_test_case']", "Add Test Case")
    end

    test "shows only suite projects in the project select", %{conn: conn} do
      {:ok, _prompt_project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})
      {:ok, _suite_project} = Projects.create_project(%{name: "Suite Project", type: :suite})

      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(view, "#suite_project_id-select [data-select-option]", "Suite Project")
      refute has_element?(view, "#suite_project_id-select [data-select-option]", "Prompt Project")
    end
  end

  describe "prompt selection" do
    test "updates when prompt is selected", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{name: "Test Prompt", template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      assert has_element?(view, "#suite_prompt_id-select [data-select-value]", prompt.name)
      assert has_element?(view, "pre", "Hello {{name}}")
    end

    test "shows prompt selector on mount", %{conn: conn} do
      _prompt = prompt_fixture_with_version(%{name: "Test Prompt"})

      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(
               view,
               "#suite_prompt_id-select [data-select-option][data-value='']",
               "Select a prompt"
             )

      assert has_element?(view, "#suite_prompt_id-select [data-select-option]", "Test Prompt")
    end
  end

  describe "test case management" do
    test "shows add test case button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      assert has_element?(view, "button[phx-click='add_test_case']", "Add Test Case")
    end

    test "handles test case interactions", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      # Select prompt first
      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      # Add test case
      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      assert has_element?(view, "#test_case_#{test_case_id}_var_name")
    end
  end

  describe "assertion management" do
    test "handles assertion interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/suites/new")

      # Add a test case first
      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      assert has_element?(view, "[phx-click='add_assertion'][phx-value-id='#{test_case_id}']")
    end
  end

  describe "suite creation" do
    test "creates suite with test cases successfully", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "New Suite", prompt_id: prompt.id})
      |> render_change()

      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      view
      |> render_click("add_assertion", %{"id" => test_case_id})

      view
      |> form("#suite-form",
        suite: %{
          name: "New Suite",
          prompt_id: prompt.id,
          test_cases: %{
            test_case_id => %{
              variable_values: %{
                name: "Alice"
              },
              assertions: %{
                assertion_type_0: "contains",
                assertion_value_0: "hello"
              }
            }
          }
        }
      )
      |> render_submit(%{
        "suite" => %{
          "name" => "New Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            test_case_id => %{
              "variable_values" => %{
                "name" => "Alice"
              },
              "assertions" => %{
                "assertion_type_0" => "contains",
                "assertion_value_0" => "hello"
              }
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
      |> form("#suite-form", suite: %{name: "", prompt_id: ""})
      |> render_submit(%{
        "suite" => %{
          "name" => "",
          "prompt_id" => ""
        }
      })

      assert has_element?(view, "p.text-error", "can't be blank")
    end

    test "validates JSON assertions", %{conn: conn} do
      prompt = prompt_fixture_with_version()

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      view
      |> render_click("toggle_assertion_mode", %{"id" => test_case_id})

      view
      |> form("#suite-form",
        suite: %{
          name: "Test Suite",
          prompt_id: prompt.id,
          test_cases: %{
            test_case_id => %{
              assertions_json: "{invalid json}"
            }
          }
        }
      )
      |> render_submit(%{
        "suite" => %{
          "name" => "Test Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            test_case_id => %{
              "assertions_json" => "{invalid json}"
            }
          }
        }
      })

      assert has_element?(view, "#flash-error", "Invalid JSON")
    end

    test "rejects invalid assertion types in JSON", %{conn: conn} do
      prompt = prompt_fixture_with_version()

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      view
      |> render_click("toggle_assertion_mode", %{"id" => test_case_id})

      view
      |> form("#suite-form",
        suite: %{
          name: "Test Suite",
          prompt_id: prompt.id,
          test_cases: %{
            test_case_id => %{
              assertions_json: ~s([{"type": "invalid_type", "value": "test"}])
            }
          }
        }
      )
      |> render_submit(%{
        "suite" => %{
          "name" => "Test Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            test_case_id => %{
              "assertions_json" => ~s([{"type": "invalid_type", "value": "test"}])
            }
          }
        }
      })

      assert has_element?(view, "#flash-error", "Invalid assertion type")
    end

    test "rejects invalid assertion types in visual mode", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      view
      |> render_click("add_assertion", %{"id" => test_case_id})

      render_submit(view, "save", %{
        "suite" => %{
          "name" => "Test Suite",
          "prompt_id" => prompt.id,
          "test_cases" => %{
            test_case_id => %{
              "variable_values" => %{"name" => "Alice"},
              "assertions" => %{
                "assertion_type_0" => "invalid_type",
                "assertion_value_0" => "test"
              }
            }
          }
        }
      })

      assert has_element?(view, "#flash-error", "Invalid assertion type")
    end

    test "uses nested variable inputs after prompt selection", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "", prompt_id: prompt.id})
      |> render_change()

      view
      |> element("[phx-click='add_test_case']")
      |> render_click()

      test_case_id = List.first(:sys.get_state(view.pid).socket.assigns.test_cases).id

      assert has_element?(view, "#test_case_#{test_case_id}_var_name")
    end

    test "changing prompt preserves other form fields", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})

      {:ok, view, _html} = live(conn, "/suites/new")

      view
      |> form("#suite-form", suite: %{name: "Suite Draft", prompt_id: prompt.id})
      |> render_change()

      assert has_element?(view, "#suite_name[value='Suite Draft']")
      assert has_element?(view, "#suite_prompt_id-select [data-select-value]", prompt.name)
    end
  end
end
