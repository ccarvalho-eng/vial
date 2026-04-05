defmodule Aludel.Stats.Activity do
  @moduledoc """
  Recent activity feeds and time-series activity reporting.
  """

  import Ecto.Query

  alias Aludel.Evals.SuiteRun
  alias Aludel.Runs.Run
  alias Aludel.Stats.Shared

  @spec daily_activity(integer()) :: [map()]
  def daily_activity(days \\ 30) do
    start_date = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.to_date()

    run_counts =
      from(r in Run,
        where: fragment("DATE(?)", r.inserted_at) >= ^start_date,
        group_by: fragment("DATE(?)", r.inserted_at),
        select: %{
          date: fragment("DATE(?)", r.inserted_at),
          run_count: count(r.id)
        }
      )
      |> Shared.repo().all()

    suite_counts =
      from(sr in SuiteRun,
        where: fragment("DATE(?)", sr.inserted_at) >= ^start_date,
        group_by: fragment("DATE(?)", sr.inserted_at),
        select: %{
          date: fragment("DATE(?)", sr.inserted_at),
          suite_count: count(sr.id)
        }
      )
      |> Shared.repo().all()

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

  @spec list_recent_activity(integer()) :: [map()]
  def list_recent_activity(limit \\ 10) do
    prompt_runs =
      from(r in Run,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        preload: [prompt_version: :prompt, run_results: :provider]
      )
      |> Shared.repo().all()
      |> Enum.map(&normalize_run/1)

    suite_runs =
      from(sr in SuiteRun,
        order_by: [desc: sr.inserted_at],
        limit: ^limit,
        preload: [suite: :prompt, prompt_version: :prompt, provider: []]
      )
      |> Shared.repo().all()
      |> Enum.map(&normalize_suite_run/1)

    (prompt_runs ++ suite_runs)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

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
end
