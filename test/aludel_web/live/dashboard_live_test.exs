defmodule Aludel.Web.DashboardLiveTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.RunsFixtures
  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures

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
    {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")

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

  test "renders activity chart with bars when there is data", %{conn: conn} do
    run = run_fixture()
    _result = run_result_fixture(%{run_id: run.id})

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#activity-chart-container")
    assert has_element?(view, "#activity-bars")
    assert has_element?(view, ".activity-bar")
  end

  test "activity chart includes tooltip elements when there is data", %{conn: conn} do
    run = run_fixture()
    _result = run_result_fixture(%{run_id: run.id})

    {:ok, view, _html} = live(conn, "/")

    html = render(view)
    assert html =~ "id=\"activity-tooltip\""
    assert html =~ "id=\"tooltip-content\""
  end

  test "activity chart hook is attached when there is data", %{conn: conn} do
    run = run_fixture()
    _result = run_result_fixture(%{run_id: run.id})

    {:ok, view, _html} = live(conn, "/")

    html = render(view)
    assert html =~ "phx-hook=\"ActivityChart\""
  end

  test "activity chart bars have data attributes for tooltips", %{conn: conn} do
    run = run_fixture()
    _result = run_result_fixture(%{run_id: run.id})

    {:ok, view, _html} = live(conn, "/")

    html = render(view)
    assert html =~ "data-date="
    assert html =~ "data-total="
  end

  test "stat card tooltips have clear descriptions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    html = render(view)
    # Total Runs tooltip
    assert html =~ "Combined total of individual prompt runs and complete suite runs"

    # Success Rate tooltip
    assert html =~ "excludes individual prompt runs"

    # Latency tooltip
    assert html =~ "Per run"
    assert html =~ "P50 = median"

    # Total Cost tooltip
    assert html =~ "Combined costs across all prompt runs and suite runs"
  end
end
