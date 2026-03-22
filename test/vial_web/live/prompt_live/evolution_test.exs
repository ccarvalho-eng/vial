defmodule VialWeb.PromptLive.EvolutionTest do
  use VialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vial.PromptsFixtures

  alias Vial.Prompts

  describe "evolution page" do
    test "renders evolution tab for prompt", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Evolution Test"})

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}/evolution")

      assert html =~ "Evolution Test"
      assert html =~ "Evolution"
    end

    test "displays message when no versions exist", %{conn: conn} do
      prompt = prompt_fixture()

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}/evolution")

      assert html =~ "No versions"
    end

    test "displays version metrics", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Metrics Test"})
      {:ok, _v1} = Prompts.create_prompt_version(prompt, "Version 1 {{var}}")
      {:ok, _v2} = Prompts.create_prompt_version(prompt, "Version 2 {{var}}")

      {:ok, _view, html} = live(conn, ~p"/prompts/#{prompt.id}/evolution")

      assert html =~ "v1"
      assert html =~ "v2"
    end
  end
end
