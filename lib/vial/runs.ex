defmodule Vial.Runs do
  @moduledoc """
  Context for managing runs and run results.
  """

  import Ecto.Query

  alias Vial.Evals.SuiteRun
  alias Vial.LLM
  alias Vial.Providers.Provider
  alias Vial.Repo
  alias Vial.Runs.Run
  alias Vial.Runs.RunResult

  @doc """
  Lists all runs in the system.
  """
  @spec list_runs() :: [Run.t()]
  def list_runs do
    Repo.all(Run)
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
    |> Repo.all()
  end

  @doc """
  Calculates the total cost across all run results and suite runs.

  Returns the sum of cost_usd from all run_results plus avg_cost_usd
  from all suite_runs.
  """
  @spec total_cost() :: float()
  def total_cost do
    # Individual runs cost
    run_cost =
      from(rr in RunResult,
        select: sum(rr.cost_usd)
      )
      |> Repo.one() || 0.0

    # Suite runs cost
    suite_cost =
      from(sr in SuiteRun,
        where: not is_nil(sr.avg_cost_usd),
        select: sum(sr.avg_cost_usd)
      )
      |> Repo.one()

    suite_cost_float =
      if suite_cost do
        Decimal.to_float(suite_cost)
      else
        0.0
      end

    run_cost + suite_cost_float
  end

  @doc """
  Gets a run by ID, raising if not found.

  Preloads run_results and their associated providers, as well as
  the prompt through the prompt_version.
  """
  @spec get_run!(binary()) :: Run.t()
  def get_run!(id) do
    Run
    |> Repo.get!(id)
    |> Repo.preload(prompt_version: :prompt, run_results: :provider)
  end

  @doc """
  Creates a new run.
  """
  @spec create_run(map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing run.
  """
  @spec update_run(Run.t(), map()) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a run.
  """
  @spec delete_run(Run.t()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def delete_run(%Run{} = run) do
    Repo.delete(run)
  end

  @doc """
  Returns a changeset for tracking run changes.
  """
  @spec change_run(Run.t(), map()) :: Ecto.Changeset.t()
  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  @doc """
  Creates a new run result.
  """
  @spec create_run_result(map()) ::
          {:ok, RunResult.t()} | {:error, Ecto.Changeset.t()}
  def create_run_result(attrs \\ %{}) do
    %RunResult{}
    |> RunResult.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing run result.
  """
  @spec update_run_result(RunResult.t(), map()) ::
          {:ok, RunResult.t()} | {:error, Ecto.Changeset.t()}
  def update_run_result(%RunResult{} = run_result, attrs) do
    run_result
    |> RunResult.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Executes a run against multiple providers concurrently.

  Renders the prompt template with variable values, calls each
  provider's LLM, broadcasts real-time updates via PubSub, and
  creates run_results for each provider.

  ## Parameters
    - run: Run struct with preloaded prompt_version
    - providers: List of provider structs to execute against

  ## Returns
    - `{:ok, run}` with preloaded run_results on success
    - `{:error, reason}` if execution fails

  ## Examples

      iex> run = Repo.preload(run, :prompt_version)
      iex> {:ok, executed_run} = execute_run(run, [provider1, provider2])
      iex> length(executed_run.run_results)
      2
  """
  @spec execute_run(Run.t(), list(Provider.t())) ::
          {:ok, Run.t()} | {:error, term()}
  def execute_run(%Run{} = run, providers) when is_list(providers) do
    rendered_prompt =
      render_template(
        run.prompt_version.template,
        run.variable_values
      )

    _results =
      Task.Supervisor.async_stream(
        Vial.TaskSupervisor,
        providers,
        fn provider ->
          execute_provider(run, provider, rendered_prompt)
        end,
        max_concurrency: 3,
        timeout: 120_000
      )
      |> Enum.to_list()

    case Repo.get(Run, run.id) do
      nil -> {:error, :run_not_found}
      updated_run -> {:ok, Repo.preload(updated_run, :run_results)}
    end
  end

  # Private helper functions

  defp render_template(template, variable_values) do
    Enum.reduce(variable_values, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end

  defp execute_provider(run, provider, rendered_prompt) do
    case LLM.call(provider, rendered_prompt) do
      {:ok, result} ->
        case create_run_result(%{
               run_id: run.id,
               provider_id: provider.id,
               output: result.output,
               input_tokens: result.input_tokens,
               output_tokens: result.output_tokens,
               latency_ms: result.latency_ms,
               cost_usd: result.cost_usd,
               status: :completed
             }) do
          {:ok, run_result} ->
            broadcast_update(run.id, run_result.id, :completed, result.output)
            {:ok, run_result}

          {:error, _changeset} ->
            # Run might have been deleted, ignore
            {:ok, nil}
        end

      {:error, reason} ->
        case create_run_result(%{
               run_id: run.id,
               provider_id: provider.id,
               status: :error,
               error: inspect(reason)
             }) do
          {:ok, run_result} ->
            broadcast_update(run.id, run_result.id, :error, inspect(reason))
            {:error, reason}

          {:error, _changeset} ->
            # Run might have been deleted, ignore
            {:error, reason}
        end
    end
  end

  defp broadcast_update(run_id, result_id, status, output) do
    Phoenix.PubSub.broadcast(
      Vial.PubSub,
      "run:#{run_id}",
      {:run_result_update, result_id, status, output}
    )
  end
end
