defmodule Aludel.Web.PromptLive.NewTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  alias Aludel.Projects
  alias Aludel.Prompts

  describe "new prompt" do
    test "renders new prompt form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prompts/new")

      assert html =~ "New Prompt"
      assert html =~ "name"
      assert html =~ "description"
      assert html =~ "tags"
      assert html =~ "template"
    end

    test "creates new prompt with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prompts/new")

      # Send tags directly as comma-separated string - bypasses TagInput hook
      result =
        view
        |> element("#prompt-form")
        |> render_submit(%{
          prompt: %{
            name: "Test Prompt",
            description: "Test description",
            tags: "elixir, test",
            template: "Hello {{name}}, welcome to {{topic}}"
          }
        })

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "/prompts/"

      # Verify tags were saved
      prompt_id = path |> String.split("/") |> List.last()
      created_prompt = Aludel.Prompts.get_prompt!(prompt_id)
      assert created_prompt.tags == ["elixir", "test"]

      prompt_with_versions = Prompts.get_prompt_with_versions!(prompt_id)
      assert length(prompt_with_versions.versions) == 1
      assert hd(prompt_with_versions.versions).template == "Hello {{name}}, welcome to {{topic}}"
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prompts/new")

      html =
        view
        |> form("#prompt-form", prompt: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "displays extracted variables preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prompts/new")

      html =
        view
        |> form("#prompt-form",
          prompt: %{template: "Hello {{user}}, your {{item}} is ready"}
        )
        |> render_change()

      assert html =~ "user"
      assert html =~ "item"
    end

    test "shows only prompt projects in the project select", %{conn: conn} do
      {:ok, _prompt_project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})
      {:ok, _suite_project} = Projects.create_project(%{name: "Suite Project", type: :suite})

      {:ok, view, _html} = live(conn, "/prompts/new")

      assert has_element?(view, "#prompt_project_id option", "Prompt Project")
      refute has_element?(view, "#prompt_project_id option", "Suite Project")
    end
  end

  describe "edit prompt" do
    test "renders edit form with existing prompt", %{conn: conn} do
      prompt =
        prompt_fixture(%{
          name: "Existing Prompt",
          description: "Existing description",
          tags: ["existing"]
        })

      {:ok, _view, html} = live(conn, "/prompts/#{prompt.id}/edit")

      assert html =~ "Edit Prompt"
      assert html =~ "Existing Prompt"
      assert html =~ "Existing description"
    end

    test "updates prompt and creates new version", %{conn: conn} do
      prompt =
        prompt_fixture_with_version(%{
          name: "Original",
          tags: ["old"],
          template: "Original template {{name}}"
        })

      {:ok, view, _html} = live(conn, "/prompts/#{prompt.id}/edit")

      result =
        view
        |> element("#prompt-form")
        |> render_submit(%{
          prompt: %{
            name: "Updated",
            tags: "new, updated",
            template: "New template with {{var}}"
          }
        })

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path == "/prompts/#{prompt.id}"

      # Verify tags were updated
      updated_prompt = Aludel.Prompts.get_prompt!(prompt.id)
      assert updated_prompt.tags == ["new", "updated"]

      prompt_with_versions = Prompts.get_prompt_with_versions!(prompt.id)
      assert Enum.map(prompt_with_versions.versions, & &1.version) == [2, 1]
      assert hd(prompt_with_versions.versions).template == "New template with {{var}}"
    end

    test "shows validation errors on edit", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Test"})

      {:ok, view, _html} = live(conn, "/prompts/#{prompt.id}/edit")

      html =
        view
        |> form("#prompt-form", prompt: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end
end
