defmodule Aludel.Stats.Overview do
  @moduledoc """
  Top-line dashboard metrics and period comparisons.
  """

  import Ecto.Query

  alias Aludel.Evals.SuiteRun
  alias Aludel.Runs.{Run, RunResult}
  alias Aludel.Stats.Shared

  @spec total_runs() :: integer()
  def total_runs do
    suite_runs = from(sr in SuiteRun, select: count(sr.id)) |> Shared.repo().one()
    prompt_runs = from(r in Run, select: count(r.id)) |> Shared.repo().one()

    suite_runs + prompt_runs
  end

  @spec test_totals() :: {integer(), integer()}
  def test_totals do
    query =
      from sr in SuiteRun,
        select: %{
          total_passed: sum(sr.passed),
          total_failed: sum(sr.failed)
        }

    result = Shared.repo().one(query)

    passed = Shared.to_integer(result.total_passed)
    failed = Shared.to_integer(result.total_failed)

    {passed, failed}
  end

  @spec success_rate(integer(), integer()) :: float()
  def success_rate(passed, failed) do
    total = passed + failed
    if total > 0, do: Float.round(passed / total * 100, 1), else: 0.0
  end

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

  @spec avg_latency() :: number()
  def avg_latency do
    query =
      from rr in RunResult,
        where: not is_nil(rr.latency_ms),
        select: avg(rr.latency_ms)

    case Shared.repo().one(query) do
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

  defp period_stats(start_time, end_time) do
    suite_runs =
      from(sr in SuiteRun, where: sr.inserted_at >= ^start_time and sr.inserted_at < ^end_time)
      |> Shared.repo().aggregate(:count)

    prompt_runs =
      from(r in Run, where: r.inserted_at >= ^start_time and r.inserted_at < ^end_time)
      |> Shared.repo().aggregate(:count)

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
end
