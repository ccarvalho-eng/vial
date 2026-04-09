defmodule Aludel.Runs.Executor do
  @moduledoc """
  Owns run launch and provider execution under explicit supervision.
  """

  require Logger

  alias Aludel.LLM
  alias Aludel.Providers.Provider
  alias Aludel.PubSub
  alias Aludel.Runs.{Execution, Run, RunResult}
  alias Ecto.Changeset

  @execution_supervisor Aludel.Runs.ExecutorSupervisor
  @default_max_concurrency 3
  @default_timeout_ms 120_000

  @type execution_result :: {:ok, Execution.t()} | {:error, :empty_providers | term()}

  @doc """
  Launches a run under the executor supervisor.
  """
  @spec launch(Run.t(), [Provider.t()]) ::
          DynamicSupervisor.on_start_child() | {:error, :empty_providers}
  def launch(%Run{}, []), do: {:error, :empty_providers}

  def launch(%Run{} = run, providers) when is_list(providers) do
    Task.Supervisor.start_child(@execution_supervisor, fn ->
      case execute(run, providers) do
        {:ok, %Execution{status: :ok}} ->
          :ok

        {:ok, %Execution{status: status, failures: failures}} ->
          Logger.warning(
            "Run execution completed with provider failures for run #{run.id} " <>
              "(status=#{status}, failures=#{inspect(failures)})"
          )

          :ok

        {:error, reason} ->
          Logger.error("Run execution failed for run #{run.id}: #{inspect(reason)}")

          :error
      end
    end)
  end

  @doc """
  Executes a run against one or more providers and returns a structured outcome.
  """
  @spec execute(Run.t(), [Provider.t()]) :: execution_result()
  def execute(%Run{}, []), do: {:error, :empty_providers}

  def execute(%Run{} = run, providers) when is_list(providers) do
    run = preload_prompt_version(run)
    rendered_prompt = render_template(run.prompt_version.template, run.variable_values)
    provider_outcomes = execute_providers(run, providers, rendered_prompt)

    with {:ok, updated_run} <- reload_run(run.id) do
      failures = collect_failures(provider_outcomes)

      {:ok,
       %Execution{
         failures: failures,
         provider_results: updated_run.run_results,
         run: updated_run,
         status: execution_status(length(providers), length(failures))
       }}
    end
  end

  defp preload_prompt_version(%Run{prompt_version: %Ecto.Association.NotLoaded{}} = run) do
    repo().preload(run, :prompt_version)
  end

  defp preload_prompt_version(%Run{} = run), do: run

  defp execute_providers(run, providers, rendered_prompt) do
    case execution_mode() do
      :sequential ->
        Enum.map(providers, fn provider ->
          {provider, execute_provider(run, provider, rendered_prompt)}
        end)

      _mode ->
        stream_provider_executions(run, providers, rendered_prompt)
    end
  end

  defp stream_provider_executions(run, providers, rendered_prompt) do
    providers
    |> Enum.zip(
      Task.Supervisor.async_stream_nolink(
        @execution_supervisor,
        providers,
        fn provider ->
          execute_provider(run, provider, rendered_prompt)
        end,
        max_concurrency: execution_max_concurrency(),
        timeout: execution_timeout_ms()
      )
    )
    |> Enum.map(fn
      {provider, {:ok, outcome}} ->
        {provider, outcome}

      {provider, {:exit, reason}} ->
        {provider, create_error_result(run, provider, {:task_exit, reason})}
    end)
  end

  defp execute_provider(run, provider, rendered_prompt) do
    case LLM.call(provider, rendered_prompt) do
      {:ok, result} ->
        create_completed_result(run, provider, result)

      {:error, reason} ->
        create_error_result(run, provider, reason)
    end
  end

  defp create_completed_result(run, provider, result) do
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

      {:error, changeset} ->
        log_run_result_failure(run.id, provider.id, changeset)
        {:error, provider_failure(provider, {:result_persistence_failed, changeset.errors})}
    end
  end

  defp create_error_result(run, provider, reason) do
    inspected_reason = inspect(reason)

    case create_run_result(%{
           run_id: run.id,
           provider_id: provider.id,
           status: :error,
           error: inspected_reason
         }) do
      {:ok, run_result} ->
        broadcast_update(run.id, run_result.id, :error, inspected_reason)
        {:error, provider_failure(provider, reason)}

      {:error, changeset} ->
        log_run_result_failure(run.id, provider.id, changeset)
        {:error, provider_failure(provider, {:result_persistence_failed, changeset.errors})}
    end
  end

  defp collect_failures(provider_outcomes) do
    Enum.reduce(provider_outcomes, [], fn
      {_provider, {:ok, _run_result}}, failures ->
        failures

      {_provider, {:error, failure}}, failures ->
        [failure | failures]
    end)
    |> Enum.reverse()
  end

  defp execution_status(_provider_count, 0), do: :ok

  defp execution_status(provider_count, failure_count) when provider_count == failure_count do
    :error
  end

  defp execution_status(_provider_count, _failure_count), do: :partial_failure

  defp provider_failure(provider, reason) do
    %{
      provider_id: provider.id,
      provider_name: provider.name,
      reason: reason
    }
  end

  defp reload_run(run_id) do
    case repo().get(Run, run_id) do
      nil ->
        {:error, :run_not_found}

      run ->
        {:ok, repo().preload(run, prompt_version: :prompt, run_results: :provider)}
    end
  end

  defp render_template(template, variable_values) do
    Enum.reduce(variable_values, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end

  defp create_run_result(attrs) do
    %RunResult{}
    |> RunResult.changeset(attrs)
    |> repo().insert()
  end

  defp log_run_result_failure(run_id, provider_id, %Changeset{} = changeset) do
    Logger.warning("Failed to create run result for run #{run_id}",
      provider_id: provider_id,
      reason: inspect(changeset.errors)
    )
  end

  defp broadcast_update(run_id, result_id, status, output) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "run:#{run_id}",
      {:run_result_update, result_id, status, output}
    )
  end

  defp execution_mode do
    Application.get_env(:aludel, :run_execution_mode, :concurrent)
  end

  defp execution_max_concurrency do
    Keyword.get(llm_config(), :max_concurrency, @default_max_concurrency)
  end

  defp execution_timeout_ms do
    Keyword.get(llm_config(), :request_timeout_ms, @default_timeout_ms)
  end

  defp llm_config do
    Application.get_env(:aludel, :llm, [])
  end

  defp repo, do: Aludel.Repo.get()
end
