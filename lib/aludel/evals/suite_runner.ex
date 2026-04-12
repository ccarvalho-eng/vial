defmodule Aludel.Evals.SuiteRunner do
  @moduledoc """
  Launches suite execution under supervision and reports completion
  back to the requesting process.
  """

  alias Aludel.Evals
  alias Aludel.Prompts
  alias Aludel.Providers
  alias Aludel.TaskSupervisor

  @spec launch(pid(), binary(), binary(), binary()) :: {:ok, pid()} | {:error, term()}
  def launch(recipient, suite_id, version_id, provider_id)
      when is_pid(recipient) and is_binary(suite_id) and is_binary(version_id) and
             is_binary(provider_id) do
    Task.Supervisor.start_child(TaskSupervisor, fn ->
      version = Prompts.get_prompt_version!(version_id)
      provider = Providers.get_provider!(provider_id)
      suite = Evals.get_suite_with_test_cases!(suite_id)

      result = Evals.execute_suite(suite, version, provider)
      send(recipient, {:suite_completed, result})
    end)
  end
end
