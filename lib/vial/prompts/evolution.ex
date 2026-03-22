defmodule Vial.Prompts.Evolution do
  @moduledoc """
  Functions for analyzing prompt version evolution and performance
  metrics.
  """

  import Ecto.Query

  alias Vial.Evals.SuiteRun
  alias Vial.Prompts.PromptVersion
  alias Vial.Providers.Provider
  alias Vial.Repo
  alias Vial.Runs.RunResult

  @doc """
  Returns aggregated metrics for all versions of a prompt.

  Returns list of maps with structure:
  - version_id: binary_id
  - version_number: integer
  - created_at: datetime
  - total_runs: integer (includes both suite runs and prompt runs)
  - avg_pass_rate: float | nil
  - avg_cost_usd: float | nil
  - avg_latency_ms: float | nil
  - provider_breakdown: list of provider-specific metrics
  """
  @spec get_metrics(binary()) :: [map()]
  def get_metrics(prompt_id) do
    prompt_id
    |> get_versions()
    |> Enum.map(&build_version_metrics/1)
  end

  defp get_versions(prompt_id) do
    PromptVersion
    |> where([v], v.prompt_id == ^prompt_id)
    |> order_by([v], asc: v.version)
    |> Repo.all()
  end

  defp build_version_metrics(version) do
    suite_runs = get_suite_runs(version.id)
    run_results = get_run_results(version.id)

    %{
      version_id: version.id,
      version_number: version.version,
      created_at: version.inserted_at,
      total_runs: length(suite_runs) + length(run_results),
      avg_pass_rate: calculate_avg_pass_rate(suite_runs),
      avg_cost_usd: calculate_avg_cost(run_results),
      avg_latency_ms: calculate_avg_latency(run_results),
      provider_breakdown: build_provider_breakdown(suite_runs)
    }
  end

  defp get_suite_runs(version_id) do
    SuiteRun
    |> where([sr], sr.prompt_version_id == ^version_id)
    |> Repo.all()
  end

  defp get_run_results(version_id) do
    RunResult
    |> join(:inner, [rr], r in assoc(rr, :run))
    |> where([rr, r], r.prompt_version_id == ^version_id)
    |> where([rr], rr.status == :completed)
    |> Repo.all()
  end

  defp calculate_avg_pass_rate([]), do: nil

  defp calculate_avg_pass_rate(suite_runs) do
    total_tests =
      Enum.reduce(suite_runs, 0, fn sr, acc ->
        acc + sr.passed + sr.failed
      end)

    if total_tests == 0 do
      nil
    else
      total_passed = Enum.reduce(suite_runs, 0, fn sr, acc -> acc + sr.passed end)
      Float.round(total_passed / total_tests * 100, 2)
    end
  end

  defp calculate_avg_cost([]), do: nil

  defp calculate_avg_cost(run_results) do
    costs = Enum.map(run_results, & &1.cost_usd) |> Enum.reject(&is_nil/1)

    if Enum.empty?(costs) do
      nil
    else
      avg = Enum.sum(costs) / length(costs)
      Float.round(avg, 4)
    end
  end

  defp calculate_avg_latency([]), do: nil

  defp calculate_avg_latency(run_results) do
    latencies = Enum.map(run_results, & &1.latency_ms) |> Enum.reject(&is_nil/1)

    if Enum.empty?(latencies) do
      nil
    else
      round(Enum.sum(latencies) / length(latencies))
    end
  end

  defp build_provider_breakdown([]), do: []

  defp build_provider_breakdown(suite_runs) do
    suite_runs
    |> Enum.group_by(& &1.provider_id)
    |> Enum.map(fn {provider_id, runs} ->
      provider = Repo.get!(Provider, provider_id)

      total_tests = Enum.reduce(runs, 0, fn sr, acc -> acc + sr.passed + sr.failed end)
      total_passed = Enum.reduce(runs, 0, fn sr, acc -> acc + sr.passed end)

      avg_pass_rate =
        if total_tests == 0 do
          nil
        else
          Float.round(total_passed / total_tests * 100, 2)
        end

      %{
        provider_id: provider_id,
        provider_name: provider.name,
        runs: length(runs),
        avg_pass_rate: avg_pass_rate
      }
    end)
    |> Enum.sort_by(& &1.provider_name)
  end
end
