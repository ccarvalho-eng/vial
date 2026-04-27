defmodule Aludel.Runs do
  @moduledoc """
  Context for managing runs and run results.
  """

  import Ecto.Query

  alias Aludel.Evals.SuiteRun
  alias Aludel.Providers.Provider
  alias Aludel.Runs.{Execution, Executor, Run, RunResult}
  alias Aludel.Stats.Shared
  alias Ecto.Changeset

  @doc """
  Lists all runs in the system.
  """
  @spec list_runs() :: [Run.t()]
  def list_runs do
    repo().all(Run)
  end

  @doc """
  Lists the most recent runs with preloaded associations.

  Returns up to the specified limit of runs, ordered by insertion
  time descending.
  """
  @spec list_recent_runs(integer()) :: [Run.t()]
  def list_recent_runs(limit \\ 10) do
    Run
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> preload(prompt_version: :prompt, run_results: :provider)
    |> repo().all()
  end

  @doc """
  Calculates the total cost across all run results and suite runs.

  Returns the sum of cost_usd from all run_results plus the summed
  per-test costs stored in suite_run results.
  """
  @spec total_cost() :: float()
  def total_cost do
    run_cost =
      from(rr in RunResult,
        select: sum(rr.cost_usd)
      )
      |> repo().one() || 0.0

    suite_cost =
      from(sr in SuiteRun, select: %{results: sr.results})
      |> repo().all()
      |> Enum.reduce(0.0, fn suite_run, acc ->
        acc + Shared.suite_run_total_cost(suite_run)
      end)

    run_cost + suite_cost
  end

  @doc """
  Gets a run by ID, raising if not found.

  Preloads run_results and their associated providers, as well as
  the prompt through the prompt_version.
  """
  @spec get_run!(binary()) :: Run.t()
  def get_run!(id) do
    Run
    |> repo().get!(id)
    |> repo().preload(prompt_version: :prompt, run_results: :provider)
  end

  @doc """
  Creates a new run.
  """
  @spec create_run(map()) :: {:ok, Run.t()} | {:error, Changeset.t()}
  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing run.
  """
  @spec update_run(Run.t(), map()) ::
          {:ok, Run.t()} | {:error, Changeset.t()}
  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a run.
  """
  @spec delete_run(Run.t()) :: {:ok, Run.t()} | {:error, Changeset.t()}
  def delete_run(%Run{} = run) do
    repo().delete(run)
  end

  @doc """
  Returns a changeset for tracking run changes.
  """
  @spec change_run(Run.t(), map()) :: Changeset.t()
  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  @doc """
  Creates a new run result.
  """
  @spec create_run_result(map()) ::
          {:ok, RunResult.t()} | {:error, Changeset.t()}
  def create_run_result(attrs \\ %{}) do
    %RunResult{}
    |> RunResult.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Gets a run result by ID, raising if not found.

  Preloads the associated provider so the result is ready for
  rendering without additional database lookups.
  """
  @spec get_run_result!(binary()) :: RunResult.t()
  def get_run_result!(id) do
    RunResult
    |> repo().get!(id)
    |> repo().preload(:provider)
  end

  @doc """
  Gets a run result by ID for export.

  Preloads the parent run, prompt, and provider so the payload can
  be serialized without additional lookups.
  """
  @spec get_run_result_for_export!(binary()) :: RunResult.t()
  def get_run_result_for_export!(id) do
    RunResult
    |> repo().get!(id)
    |> repo().preload([:provider, run: [prompt_version: :prompt]])
  end

  @doc """
  Updates an existing run result.
  """
  @spec update_run_result(RunResult.t(), map()) ::
          {:ok, RunResult.t()} | {:error, Changeset.t()}
  def update_run_result(%RunResult{} = run_result, attrs) do
    run_result
    |> RunResult.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Launches a run under the executor supervisor.
  """
  @spec launch_run(Run.t(), [Provider.t()]) :: DynamicSupervisor.on_start_child()
  def launch_run(%Run{} = run, providers) when is_list(providers) do
    Executor.launch(run, providers)
  end

  @doc """
  Executes a run through the executor service and returns a structured outcome.
  """
  @spec execute_run(Run.t(), [Provider.t()]) ::
          {:ok, Execution.t()} | {:error, term()}
  def execute_run(%Run{} = run, providers) when is_list(providers) do
    Executor.execute(run, providers)
  end

  defp repo, do: Aludel.Repo.get()
end
