defmodule Aludel.Web.PromptLive.IndexTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  alias Aludel.Projects

  test "renders list of prompts", %{conn: conn} do
    _prompt = prompt_fixture(%{name: "Test Prompt", tags: ["test"]})

    {:ok, view, _html} = live(conn, "/prompts")

    assert has_element?(view, "table")
    assert render(view) =~ "Test Prompt"
  end

  test "can navigate to new prompt form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prompts")

    assert view
           |> element("a", "New Prompt")
           |> render_click()
  end

  test "filters prompts by tag", %{conn: conn} do
    _p1 = prompt_fixture(%{name: "P1", tags: ["elixir"]})
    _p2 = prompt_fixture(%{name: "P2", tags: ["python"]})

    {:ok, view, _html} = live(conn, "/prompts?tag=elixir")

    assert render(view) =~ "P1"
    refute render(view) =~ "P2"
  end

  test "creates prompt projects with prompt type", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prompts")

    html =
      render_submit(view, "create_project", %{
        "project" => %{"name" => "Prompt Workspace"}
      })

    assert html =~ "Project created successfully"

    [project] = Projects.list_projects(type: :prompt)
    assert project.name == "Prompt Workspace"
    assert project.type == :prompt
    assert Projects.list_projects(type: :suite) == []
  end

  test "updates prompt project from edit form", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Original Prompt Project", type: :prompt})

    {:ok, view, _html} = live(conn, "/prompts")

    html =
      view
      |> form("#edit-project-form-#{project.id}",
        project: %{id: project.id, name: "Renamed Prompt Project"}
      )
      |> render_submit()

    assert html =~ "Project updated successfully"
    assert Projects.get_project!(project.id).name == "Renamed Prompt Project"
  end

  test "shows error when prompt project update is invalid", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Original Prompt Project", type: :prompt})

    {:ok, view, _html} = live(conn, "/prompts")

    html =
      view
      |> form("#edit-project-form-#{project.id}",
        project: %{id: project.id, name: "   "}
      )
      |> render_submit()

    assert html =~ "Failed to update project"
    assert Projects.get_project!(project.id).name == "Original Prompt Project"
  end
end
