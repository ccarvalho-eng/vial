defmodule Vial.Web.DashboardLiveTest do
  use Vial.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vial.RunsFixtures
  import Vial.EvalsFixtures
  import Vial.PromptsFixtures

  test "renders dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#dashboard")
    assert render(view) =~ "Dashboard"
  end

  test "shows recent runs", %{conn: conn} do
    _run = run_fixture(%{name: "Recent Test Run"})

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#recent-runs")
    assert render(view) =~ "Recent Test Run"
  end

  test "shows cost metrics", %{conn: conn} do
    run = run_fixture()
    _result = run_result_fixture(%{run_id: run.id, cost_usd: 0.05})

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#cost-summary")
    assert render(view) =~ "0.05"
  end

  test "shows pass rates per prompt", %{conn: conn} do
    prompt = prompt_fixture(%{name: "Test Prompt"})
    {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template")

    _suite_run =
      suite_run_fixture(%{
        prompt_version_id: version.id,
        passed: 5,
        failed: 2
      })

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#pass-rates")
    assert render(view) =~ "Test Prompt"
  end

  test "shows empty state when no runs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert render(view) =~ "No recent runs"
  end
end
