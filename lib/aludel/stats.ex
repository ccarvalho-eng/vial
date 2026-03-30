defmodule Aludel.Stats do
  @moduledoc """
  Context module for dashboard statistics and metrics.
  """

  import Ecto.Query

  alias Aludel.Evals.SuiteRun
  alias Aludel.Runs.{Run, RunResult}

  @doc """
  Returns total number of test runs (suite runs + prompt runs).
  """
  @spec total_runs() :: integer()
  def total_runs do
    suite_runs = from(sr in SuiteRun, select: count(sr.id)) |> repo().one()
    prompt_runs = from(r in Run, select: count(r.id)) |> repo().one()

    suite_runs + prompt_runs
  end

  @doc """
  Returns tuple of {total_passed, total_failed} test counts.
  """
  @spec test_totals() :: {integer(), integer()}
  def test_totals do
    query =
      from sr in SuiteRun,
        select: %{
          total_passed: sum(sr.passed),
          total_failed: sum(sr.failed)
        }

    result = repo().one(query)

    passed = to_integer(result.total_passed)
    failed = to_integer(result.total_failed)

    {passed, failed}
  end

  @doc """
  Calculates success rate percentage from passed and failed counts.
  """
  @spec success_rate(integer(), integer()) :: float()
  def success_rate(passed, failed) do
    total = passed + failed
    if total > 0, do: Float.round(passed / total * 100, 1), else: 0.0
  end

  @doc """
  Returns average latency in milliseconds across all run results.
  """
  @spec avg_latency() :: number()
  def avg_latency do
    query =
      from rr in RunResult,
        where: not is_nil(rr.latency_ms),
        select: avg(rr.latency_ms)

    case repo().one(query) do
      nil ->
        0

      %Decimal{} = latency ->
        latency |> Decimal.to_float() |> Float.round(0)

      latency when is_float(latency) ->
        Float.round(latency, 0)

      latency ->
        latency
    end
  end

  @doc """
  Returns latency percentiles (P50, P95) in milliseconds.
  """
  @spec latency_percentiles() :: %{p50: number(), p95: number()}
  def latency_percentiles do
    latencies =
      from(rr in RunResult,
        where: not is_nil(rr.latency_ms),
        select: rr.latency_ms,
        order_by: [asc: rr.latency_ms]
      )
      |> repo().all()
      |> Enum.map(&to_float/1)

    case latencies do
      [] ->
        %{p50: 0, p95: 0}

      latencies ->
        count = length(latencies)
        p50_idx = trunc(count * 0.5)
        p95_idx = trunc(count * 0.95)

        %{
          p50: Enum.at(latencies, p50_idx) |> Float.round(0),
          p95: Enum.at(latencies, p95_idx) |> Float.round(0)
        }
    end
  end

  @doc """
  Returns average cost per run (total cost / total runs).
  """
  @spec cost_per_run() :: float()
  def cost_per_run do
    total = total_runs()
    if total > 0, do: Aludel.Runs.total_cost() / total, else: 0.0
  end

  @doc """
  Returns stats for last N days compared to previous period.
  Returns %{current: map, previous: map, trends: map}.
  """
  @spec comparison_stats(integer()) :: map()
  def comparison_stats(days \\ 7) do
    now = DateTime.utc_now()
    period_start = DateTime.add(now, -days, :day)
    previous_start = DateTime.add(period_start, -days, :day)

    current = period_stats(period_start, now)
    previous = period_stats(previous_start, period_start)

    %{
      current: current,
      previous: previous,
      trends: calculate_trends(current, previous)
    }
  end

  @doc """
  Returns recent activity combining both Run and SuiteRun records.

  Fetches and normalizes both types of runs into a common format,
  sorted by insertion time descending.
  """
  @spec list_recent_activity(integer()) :: [map()]
  def list_recent_activity(limit \\ 10) do
    # Fetch recent prompt runs
    prompt_runs =
      from(r in Run,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        preload: [prompt_version: :prompt, run_results: :provider]
      )
      |> repo().all()
      |> Enum.map(&normalize_run/1)

    # Fetch recent suite runs
    suite_runs =
      from(sr in SuiteRun,
        order_by: [desc: sr.inserted_at],
        limit: ^limit,
        preload: [suite: :prompt, prompt_version: :prompt, provider: []]
      )
      |> repo().all()
      |> Enum.map(&normalize_suite_run/1)

    # Combine and sort by inserted_at
    (prompt_runs ++ suite_runs)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Normalizes a suite run into a common format for recent activity display.
  """
  @spec normalize_suite_run(SuiteRun.t()) :: map()
  def normalize_suite_run(suite_run) do
    %{
      id: suite_run.id,
      type: :suite_run,
      name: suite_run.suite.name,
      prompt_name:
        suite_run.prompt_version && suite_run.prompt_version.prompt &&
          suite_run.prompt_version.prompt.name,
      providers_count: 1,
      cost:
        if suite_run.avg_cost_usd do
          Decimal.to_float(suite_run.avg_cost_usd)
        else
          0.0
        end,
      passed: suite_run.passed,
      failed: suite_run.failed,
      inserted_at: suite_run.inserted_at,
      path: "/suites/#{suite_run.suite_id}"
    }
  end

  # Private functions

  defp to_integer(nil), do: 0
  defp to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  defp to_integer(value) when is_integer(value), do: value

  defp to_float(nil), do: 0.0
  defp to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value / 1

  defp period_stats(start_time, end_time) do
    suite_runs =
      from(sr in SuiteRun, where: sr.inserted_at >= ^start_time and sr.inserted_at < ^end_time)
      |> repo().aggregate(:count)

    prompt_runs =
      from(r in Run, where: r.inserted_at >= ^start_time and r.inserted_at < ^end_time)
      |> repo().aggregate(:count)

    %{total_runs: suite_runs + prompt_runs}
  end

  defp calculate_trends(current, previous) do
    %{
      total_runs: trend_direction(current.total_runs, previous.total_runs)
    }
  end

  defp trend_direction(current, previous) when previous == 0 and current > 0, do: :up
  defp trend_direction(current, previous) when current > previous, do: :up
  defp trend_direction(current, previous) when current < previous, do: :down
  defp trend_direction(_current, _previous), do: :stable

  defp normalize_run(run) do
    %{
      id: run.id,
      type: :run,
      name: run.name || "Unnamed Run",
      prompt_name:
        run.prompt_version && run.prompt_version.prompt && run.prompt_version.prompt.name,
      providers_count: length(run.run_results),
      cost: calculate_run_cost(run.run_results),
      inserted_at: run.inserted_at,
      path: "/runs/#{run.id}"
    }
  end

  defp calculate_run_cost(run_results) do
    Enum.reduce(run_results, 0.0, fn result, acc ->
      if result.cost_usd, do: acc + result.cost_usd, else: acc
    end)
  end

  defp repo do
    Application.get_env(:aludel, :repo) ||
      raise """
      Aludel repo not configured.

      Add to your config:

          config :aludel, repo: YourApp.Repo
      """
  end
end
