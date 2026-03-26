defmodule Vial.Web.PromptLive.NewTest do
  use Vial.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vial.PromptsFixtures

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

      result =
        view
        |> form("#prompt-form",
          prompt: %{
            name: "Test Prompt",
            description: "Test description",
            tags: "elixir, test",
            template: "Hello {{name}}, welcome to {{topic}}"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "/prompts/"
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
      prompt = prompt_fixture(%{name: "Original"})

      {:ok, view, _html} = live(conn, "/prompts/#{prompt.id}/edit")

      result =
        view
        |> form("#prompt-form",
          prompt: %{
            name: "Updated",
            template: "New template with {{var}}"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path == "/prompts/#{prompt.id}"
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
