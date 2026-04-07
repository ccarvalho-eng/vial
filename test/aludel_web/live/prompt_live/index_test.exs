defmodule Aludel.Web.PromptLive.IndexTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  alias Aludel.Projects
  alias Aludel.Prompts

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
    p1 = prompt_fixture(%{name: "P1", tags: ["elixir"]})
    p2 = prompt_fixture(%{name: "P2", tags: ["python"]})

    {:ok, view, _html} = live(conn, "/prompts?tag=elixir")

    assert has_element?(view, "a[href='/prompts/#{p1.id}']", "P1")
    refute has_element?(view, "a[href='/prompts/#{p2.id}']", "P2")
  end

  test "search filters prompts inside expanded projects", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})

    matching_prompt =
      prompt_fixture(%{
        name: "Alpha Prompt",
        description: "Matches search",
        project_id: project.id
      })

    hidden_prompt =
      prompt_fixture(%{
        name: "Beta Prompt",
        description: "Does not match",
        project_id: project.id
      })

    {:ok, view, _html} = live(conn, "/prompts?search=alpha")

    render_click(view, "toggle_project", %{"project_id" => project.id})

    assert has_element?(view, "a[href='/prompts/#{matching_prompt.id}']", "Alpha Prompt")
    refute has_element?(view, "a[href='/prompts/#{hidden_prompt.id}']", "Beta Prompt")
  end

  test "project prompts render all filtered matches", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})

    prompts =
      for index <- 1..21 do
        prompt_fixture(%{
          name: "Project Prompt #{index}",
          description: "Project entry #{index}",
          project_id: project.id
        })
      end

    {:ok, view, _html} = live(conn, "/prompts")

    render_click(view, "toggle_project", %{"project_id" => project.id})

    assert Enum.all?(prompts, fn prompt ->
             has_element?(view, "a[href='/prompts/#{prompt.id}']", prompt.name)
           end)
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

  test "deleting a prompt refreshes expanded project contents", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})

    prompt =
      prompt_fixture(%{
        name: "Prompt In Project",
        project_id: project.id
      })

    {:ok, view, _html} = live(conn, "/prompts")

    render_click(view, "toggle_project", %{"project_id" => project.id})

    assert has_element?(view, "tr", "Prompt In Project")

    render_click(view, "delete", %{"id" => prompt.id})

    refute has_element?(view, "tr", "Prompt In Project")

    assert Projects.list_projects(type: :prompt)
           |> Enum.find(&(&1.id == project.id))
           |> Map.get(:prompts) == []

    assert_raise Ecto.NoResultsError, fn -> Prompts.get_prompt!(prompt.id) end
  end

  test "project prompt delete modal is rendered", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})

    prompt =
      prompt_fixture(%{
        name: "Prompt In Project",
        project_id: project.id
      })

    {:ok, view, _html} = live(conn, "/prompts")

    render_click(view, "toggle_project", %{"project_id" => project.id})

    assert has_element?(view, "#confirm-delete-prompt-#{prompt.id}")
  end

  test "selected empty project remains visible", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Empty Project", type: :prompt})

    {:ok, view, _html} = live(conn, "/prompts?project_id=#{project.id}")

    assert has_element?(view, "tr", "Empty Project")
    refute render(view) =~ "No prompts yet. Create your first prompt or project to get started."
  end

  test "search trims whitespace consistently for project prompts", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})

    matching_prompt =
      prompt_fixture(%{
        name: "Alpha Prompt",
        description: "Matches search",
        project_id: project.id
      })

    {:ok, view, _html} = live(conn, "/prompts?search=%20alpha%20")

    render_click(view, "toggle_project", %{"project_id" => project.id})

    assert has_element?(view, "a[href='/prompts/#{matching_prompt.id}']", "Alpha Prompt")
  end
end
