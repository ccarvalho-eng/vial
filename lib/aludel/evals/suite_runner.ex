defmodule Aludel.Evals.SuiteRunner do
  @moduledoc """
  Owns suite execution launch under explicit supervision.
  """

  alias Aludel.Evals
  alias Aludel.Evals.SuiteRun
  alias Aludel.Prompts
  alias Aludel.Providers
  alias Aludel.TaskSupervisor

  @type execution_result :: {:ok, SuiteRun.t()} | {:error, term()}

  @spec launch(pid(), binary(), binary(), binary()) :: {:ok, pid()} | {:error, term()}
  def launch(recipient, suite_id, version_id, provider_id)
      when is_pid(recipient) and is_binary(suite_id) and is_binary(version_id) and
             is_binary(provider_id) do
    Task.Supervisor.start_child(TaskSupervisor, fn ->
      result = execute(suite_id, version_id, provider_id)
      send(recipient, {:suite_completed, result})
    end)
  end

  @spec execute(binary(), binary(), binary()) :: execution_result()
  def execute(suite_id, version_id, provider_id)
      when is_binary(suite_id) and is_binary(version_id) and is_binary(provider_id) do
    version = Prompts.get_prompt_version!(version_id)
    provider = Providers.get_provider!(provider_id)
    suite = Evals.get_suite_with_test_cases!(suite_id)

    Evals.execute_suite(suite, version, provider)
  end
end
