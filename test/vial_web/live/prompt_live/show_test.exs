defmodule VialWeb.PromptLive.ShowTest do
  use VialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vial.PromptsFixtures

  alias Vial.Prompts

  describe "show prompt" do
    test "renders prompt details", %{conn: conn} do
      prompt =
        prompt_fixture(%{
          name: "Test Prompt",
          description: "Test description",
          tags: ["test", "example"]
        })

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert html =~ "Test Prompt"
      assert html =~ "Test description"
      assert html =~ "test"
      assert html =~ "example"
    end

    test "displays all versions ordered by version desc", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Versioned Prompt"})

      # Create versions
      {:ok, v1} = Prompts.create_prompt_version(prompt, "Version 1 template")
      {:ok, v2} = Prompts.create_prompt_version(prompt, "Version 2 template")
      {:ok, v3} = Prompts.create_prompt_version(prompt, "Version 3 template")

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}")

      # Check all versions are displayed
      assert html =~ "Version 1 template"
      assert html =~ "Version 2 template"
      assert html =~ "Version 3 template"

      # Check version numbers
      assert html =~ "v#{v1.version}"
      assert html =~ "v#{v2.version}"
      assert html =~ "v#{v3.version}"
    end

    test "displays version variables", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Variable Test"})

      {:ok, _version} =
        Prompts.create_prompt_version(
          prompt,
          "Hello {{name}}, welcome to {{topic}}"
        )

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert html =~ "name"
      assert html =~ "topic"
    end

    test "shows edit button linking to edit page", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Editable Prompt"})

      {:ok, view, _html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert has_element?(view, "a[href=\"/prompts/#{prompt.id}/edit\"]")
    end

    test "shows back button to index", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Test Prompt"})

      {:ok, view, _html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert has_element?(view, "a[href=\"/prompts\"]")
    end

    test "raises 404 for non-existent prompt", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/prompts/#{fake_id}")
      end
    end

    test "displays message when prompt has no versions", %{conn: conn} do
      prompt = prompt_fixture(%{name: "No Versions"})

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert html =~ "No versions"
    end

    test "can navigate to create run", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Test Prompt"})
      {:ok, version} = Prompts.create_prompt_version(prompt, "Hello {{name}}")

      {:ok, view, _html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert has_element?(
               view,
               "a[href*='/runs/new'][href*='version=#{version.id}']"
             )
    end

    test "shows evolution tab link", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Test Prompt"})

      {:ok, view, _html} = live(conn, ~p"/prompts/#{prompt.id}")

      assert has_element?(view, "a[href=\"/prompts/#{prompt.id}/evolution\"]")
    end
  end
end
