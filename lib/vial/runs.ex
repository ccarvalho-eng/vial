defmodule Vial.Runs do
  @moduledoc """
  Context for managing runs and run results.

  In embedded mode, all functions accept a repo as the first parameter.
  For standalone mode, you can pass Vial.Repo directly.
  """

  import Ecto.Query

  alias Vial.Evals.SuiteRun
  alias Vial.LLM
  alias Vial.Providers.Provider
  alias Vial.Runs.Run
  alias Vial.Runs.RunResult

  @doc """
  Lists all runs in the system.
  """
  @spec list_runs(module()) :: [Run.t()]
  def list_runs(repo) do
    repo.all(Run)
  end

  @doc """
  Lists the most recent runs with preloaded associations.

  Returns up to the specified limit of runs, ordered by insertion
  time descending.
  """
  @spec list_recent_runs(module(), integer()) :: [Run.t()]
  def list_recent_runs(repo, limit \\ 10) do
    Run
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> preload(prompt_version: :prompt, run_results: :provider)
    |> repo.all()
  end

  @doc """
  Calculates the total cost across all run results and suite runs.

  Returns the sum of cost_usd from all run_results plus avg_cost_usd
  from all suite_runs.
  """
  @spec total_cost(module()) :: float()
  def total_cost(repo) do
    # Individual runs cost
    run_cost =
      from(rr in RunResult,
        select: sum(rr.cost_usd)
      )
      |> repo.one() || 0.0

    # Suite runs cost
    suite_cost =
      from(sr in SuiteRun,
        where: not is_nil(sr.avg_cost_usd),
        select: sum(sr.avg_cost_usd)
      )
      |> repo.one()

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
  @spec get_run!(module(), binary()) :: Run.t()
  def get_run!(repo, id) do
    Run
    |> repo.get!(id)
    |> repo.preload(prompt_version: :prompt, run_results: :provider)
  end

  @doc """
  Creates a new run.
  """
  @spec create_run(module(), map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create_run(repo, attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing run.
  """
  @spec update_run(module(), Run.t(), map()) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def update_run(repo, %Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Deletes a run.
  """
  @spec delete_run(module(), Run.t()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def delete_run(repo, %Run{} = run) do
    repo.delete(run)
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
  @spec create_run_result(module(), map()) ::
          {:ok, RunResult.t()} | {:error, Ecto.Changeset.t()}
  def create_run_result(repo, attrs \\ %{}) do
    %RunResult{}
    |> RunResult.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing run result.
  """
  @spec update_run_result(module(), RunResult.t(), map()) ::
          {:ok, RunResult.t()} | {:error, Ecto.Changeset.t()}
  def update_run_result(repo, %RunResult{} = run_result, attrs) do
    run_result
    |> RunResult.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Executes a run against multiple providers concurrently.

  Renders the prompt template with variable values, calls each
  provider's LLM, broadcasts real-time updates via PubSub, and
  creates run_results for each provider.

  ## Parameters
    - repo: The repo to use for database operations
    - run: Run struct with preloaded prompt_version
    - providers: List of provider structs to execute against
    - pubsub: Optional PubSub module for broadcasting updates
    - task_supervisor: Optional TaskSupervisor for async execution

  ## Returns
    - `{:ok, run}` with preloaded run_results on success
    - `{:error, reason}` if execution fails

  ## Examples

      iex> run = repo.preload(run, :prompt_version)
      iex> {:ok, executed_run} = execute_run(repo, run, [provider1, provider2])
      iex> length(executed_run.run_results)
      2
  """
  @spec execute_run(module(), Run.t(), list(Provider.t()), module() | nil, module() | nil) ::
          {:ok, Run.t()} | {:error, term()}
  def execute_run(repo, %Run{} = run, providers, pubsub \\ nil, task_supervisor \\ nil)
      when is_list(providers) do
    rendered_prompt =
      render_template(
        run.prompt_version.template,
        run.variable_values
      )

    supervisor = task_supervisor || Vial.TaskSupervisor

    _results =
      Task.Supervisor.async_stream(
        supervisor,
        providers,
        fn provider ->
          execute_provider(repo, run, provider, rendered_prompt, pubsub)
        end,
        max_concurrency: 3,
        timeout: 120_000
      )
      |> Enum.to_list()

    case repo.get(Run, run.id) do
      nil -> {:error, :run_not_found}
      updated_run -> {:ok, repo.preload(updated_run, :run_results)}
    end
  end

  # Private helper functions

  defp render_template(template, variable_values) do
    Enum.reduce(variable_values, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end

  defp execute_provider(repo, run, provider, rendered_prompt, pubsub) do
    case LLM.call(provider, rendered_prompt) do
      {:ok, result} ->
        case create_run_result(repo, %{
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
            broadcast_update(run.id, run_result.id, :completed, result.output, pubsub)
            {:ok, run_result}

          {:error, _changeset} ->
            # Run might have been deleted, ignore
            {:ok, nil}
        end

      {:error, reason} ->
        case create_run_result(repo, %{
               run_id: run.id,
               provider_id: provider.id,
               status: :error,
               error: inspect(reason)
             }) do
          {:ok, run_result} ->
            broadcast_update(run.id, run_result.id, :error, inspect(reason), pubsub)
            {:error, reason}

          {:error, _changeset} ->
            # Run might have been deleted, ignore
            {:error, reason}
        end
    end
  end

  defp broadcast_update(run_id, result_id, status, output, pubsub) do
    if pubsub do
      Phoenix.PubSub.broadcast(
        pubsub,
        "run:#{run_id}",
        {:run_result_update, result_id, status, output}
      )
    end
  end
end
