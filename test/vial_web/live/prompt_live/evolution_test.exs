defmodule Vial.Web.PromptLive.EvolutionTest do
  use Vial.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures
  import Vial.EvalsFixtures

  alias Vial.Prompts

  describe "evolution page" do
    test "renders evolution tab for prompt", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Evolution Test"})

      {:ok, _view, html} = live(conn, "/prompts/#{prompt.id}/evolution")

      assert html =~ "Evolution Test"
      assert html =~ "Evolution"
    end

    test "displays message when no versions exist", %{conn: conn} do
      prompt = prompt_fixture()

      {:ok, _view, html} = live(conn, "/prompts/#{prompt.id}/evolution")

      assert html =~ "No versions"
    end

    test "displays version metrics", %{conn: conn} do
      prompt = prompt_fixture(%{name: "Metrics Test"})
      {:ok, _v1} = Prompts.create_prompt_version(prompt, "Version 1 {{var}}")
      {:ok, _v2} = Prompts.create_prompt_version(prompt, "Version 2 {{var}}")

      {:ok, _view, html} = live(conn, "/prompts/#{prompt.id}/evolution")

      assert html =~ "v1"
      assert html =~ "v2"
    end

    test "displays provider breakdown when available", %{conn: conn} do
      prompt = prompt_fixture()
      provider = provider_fixture(%{name: "Test Provider"})
      {:ok, version} = Prompts.create_prompt_version(prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      {:ok, _sr} =
        Vial.Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 8,
          failed: 2
        })

      {:ok, _view, html} = live(conn, "/prompts/#{prompt.id}/evolution")

      assert html =~ "Test Provider"
      assert html =~ "80.0%"
    end
  end

  describe "chart functionality" do
    test "assigns chart data on mount", %{conn: conn} do
      prompt = prompt_fixture()

      {:ok, view, _html} = live(conn, "/prompts/#{prompt.id}/evolution")

      state = :sys.get_state(view.pid)
      socket = state.socket

      assert socket.assigns.chart_data
      assert socket.assigns.view_mode == :overall
    end

    test "toggles view mode", %{conn: conn} do
      prompt = prompt_fixture()

      {:ok, view, _html} = live(conn, "/prompts/#{prompt.id}/evolution")

      state = :sys.get_state(view.pid)
      socket = state.socket
      assert socket.assigns.view_mode == :overall

      render_click(view, "toggle_view_mode")

      state = :sys.get_state(view.pid)
      socket = state.socket
      assert socket.assigns.view_mode == :by_provider
    end
  end
end
