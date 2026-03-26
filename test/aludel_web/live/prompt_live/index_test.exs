defmodule Aludel.Web.PromptLive.IndexTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures

  test "renders list of prompts", %{conn: conn} do
    _prompt = prompt_fixture(%{name: "Test Prompt", tags: ["test"]})

    {:ok, view, _html} = live(conn, "/prompts")

    assert has_element?(view, "#prompts")
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
end
