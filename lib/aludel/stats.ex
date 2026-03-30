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
        p50_idx = max(0, trunc(count * 0.5) - 1)
        p95_idx = max(0, trunc(count * 0.95) - 1)

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
  Returns cost breakdown by provider.
  """
  @spec cost_by_provider() :: [map()]
  def cost_by_provider do
    # Costs from run results
    run_costs =
      from(rr in RunResult,
        join: p in assoc(rr, :provider),
        where: not is_nil(rr.cost_usd),
        group_by: [p.id, p.name],
        select: %{
          provider_id: p.id,
          provider_name: p.name,
          total_cost: sum(rr.cost_usd),
          run_count: count(rr.id)
        }
      )
      |> repo().all()

    # Costs from suite runs
    suite_costs =
      from(sr in SuiteRun,
        join: p in assoc(sr, :provider),
        where: not is_nil(sr.avg_cost_usd),
        group_by: [p.id, p.name],
        select: %{
          provider_id: p.id,
          provider_name: p.name,
          total_cost: sum(sr.avg_cost_usd),
          run_count: count(sr.id)
        }
      )
      |> repo().all()

    # Merge costs by provider
    (run_costs ++ suite_costs)
    |> Enum.group_by(& &1.provider_id)
    |> Enum.map(fn {_provider_id, entries} ->
      total_cost =
        Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
          cost_decimal =
            if is_float(entry.total_cost) or is_integer(entry.total_cost) do
              Decimal.from_float(entry.total_cost / 1)
            else
              entry.total_cost
            end

          Decimal.add(acc, cost_decimal)
        end)

      run_count = Enum.sum(Enum.map(entries, & &1.run_count))

      %{
        provider_name: List.first(entries).provider_name,
        total_cost: Decimal.to_float(total_cost),
        run_count: run_count,
        avg_cost: Decimal.to_float(Decimal.div(total_cost, run_count))
      }
    end)
    |> Enum.sort_by(& &1.total_cost, :desc)
  end

  @doc """
  Returns cost breakdown by prompt.
  """
  @spec cost_by_prompt() :: [map()]
  def cost_by_prompt do
    # Costs from run results
    run_costs =
      from(rr in RunResult,
        join: r in assoc(rr, :run),
        join: pv in assoc(r, :prompt_version),
        join: p in assoc(pv, :prompt),
        where: not is_nil(rr.cost_usd),
        group_by: [p.id, p.name],
        select: %{
          prompt_id: p.id,
          prompt_name: p.name,
          total_cost: sum(rr.cost_usd),
          run_count: count(rr.id)
        }
      )
      |> repo().all()

    # Costs from suite runs
    suite_costs =
      from(sr in SuiteRun,
        join: pv in assoc(sr, :prompt_version),
        join: p in assoc(pv, :prompt),
        where: not is_nil(sr.avg_cost_usd),
        group_by: [p.id, p.name],
        select: %{
          prompt_id: p.id,
          prompt_name: p.name,
          total_cost: sum(sr.avg_cost_usd),
          run_count: count(sr.id)
        }
      )
      |> repo().all()

    # Merge costs by prompt
    (run_costs ++ suite_costs)
    |> Enum.group_by(& &1.prompt_id)
    |> Enum.map(fn {_prompt_id, entries} ->
      total_cost =
        Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
          cost_decimal =
            if is_float(entry.total_cost) or is_integer(entry.total_cost) do
              Decimal.from_float(entry.total_cost / 1)
            else
              entry.total_cost
            end

          Decimal.add(acc, cost_decimal)
        end)

      run_count = Enum.sum(Enum.map(entries, & &1.run_count))

      %{
        prompt_name: List.first(entries).prompt_name,
        total_cost: Decimal.to_float(total_cost),
        run_count: run_count,
        avg_cost: Decimal.to_float(Decimal.div(total_cost, run_count))
      }
    end)
    |> Enum.sort_by(& &1.total_cost, :desc)
  end

  @doc """
  Returns latency stats by provider.
  """
  @spec latency_by_provider() :: [map()]
  def latency_by_provider do
    from(rr in RunResult,
      join: p in assoc(rr, :provider),
      where: not is_nil(rr.latency_ms),
      group_by: [p.id, p.name],
      select: %{
        provider_name: p.name,
        avg_latency: avg(rr.latency_ms),
        min_latency: min(rr.latency_ms),
        max_latency: max(rr.latency_ms),
        run_count: count(rr.id)
      }
    )
    |> repo().all()
    |> Enum.map(fn row ->
      %{
        provider_name: row.provider_name,
        avg_latency: to_float(row.avg_latency),
        min_latency: to_float(row.min_latency),
        max_latency: to_float(row.max_latency),
        run_count: row.run_count
      }
    end)
    |> Enum.sort_by(& &1.avg_latency)
  end

  @doc """
  Returns daily activity for the last N days.
  """
  @spec daily_activity(integer()) :: [map()]
  def daily_activity(days \\ 30) do
    start_date = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.to_date()

    # Get daily run counts
    run_counts =
      from(r in Run,
        where: fragment("DATE(?)", r.inserted_at) >= ^start_date,
        group_by: fragment("DATE(?)", r.inserted_at),
        select: %{
          date: fragment("DATE(?)", r.inserted_at),
          run_count: count(r.id)
        }
      )
      |> repo().all()

    # Get daily suite run counts
    suite_counts =
      from(sr in SuiteRun,
        where: fragment("DATE(?)", sr.inserted_at) >= ^start_date,
        group_by: fragment("DATE(?)", sr.inserted_at),
        select: %{
          date: fragment("DATE(?)", sr.inserted_at),
          suite_count: count(sr.id)
        }
      )
      |> repo().all()

    # Merge by date
    all_dates = Date.range(start_date, Date.utc_today())

    Enum.map(all_dates, fn date ->
      run_entry = Enum.find(run_counts, &(&1.date == date))
      suite_entry = Enum.find(suite_counts, &(&1.date == date))

      %{
        date: date,
        run_count: if(run_entry, do: run_entry.run_count, else: 0),
        suite_count: if(suite_entry, do: suite_entry.suite_count, else: 0),
        total:
          ((run_entry && run_entry.run_count) || 0) +
            ((suite_entry && suite_entry.suite_count) || 0)
      }
    end)
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
