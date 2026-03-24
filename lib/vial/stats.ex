defmodule Vial.Stats do
  @moduledoc """
  Context module for dashboard statistics and metrics.
  """

  import Ecto.Query

  alias Vial.Evals.SuiteRun
  alias Vial.Runs.{Run, RunResult}

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

  defp to_integer(nil), do: 0
  defp to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  defp to_integer(value) when is_integer(value), do: value

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

  defp calculate_run_cost(run_results) do
    Enum.reduce(run_results, 0.0, fn result, acc ->
      if result.cost_usd, do: acc + result.cost_usd, else: acc
    end)
  end

  defp repo do
    Application.get_env(:vial, :repo) ||
      raise """
      Vial repo not configured.

      Add to your config:

          config :vial, repo: YourApp.Repo
      """
  end
end
