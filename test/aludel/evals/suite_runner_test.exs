defmodule Aludel.Evals.SuiteRunnerTest do
  use Aludel.DataCase

  alias Aludel.Evals.SuiteRunner

  describe "execute/3" do
    test "returns a persisted suite run" do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})
      suite = suite_fixture(%{prompt_id: prompt.id})
      provider = provider_fixture()
      version = List.first(prompt.versions)

      assert {:ok, suite_run} = SuiteRunner.execute(suite.id, version.id, provider.id)
      assert suite_run.suite_id == suite.id
      assert suite_run.prompt_version_id == version.id
      assert suite_run.provider_id == provider.id
    end

    test "returns a structured error when dependent records cannot be loaded" do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})
      suite = suite_fixture(%{prompt_id: prompt.id})
      version = List.first(prompt.versions)

      assert {:error, :provider_not_found} =
               SuiteRunner.execute(suite.id, version.id, Ecto.UUID.generate())
    end
  end

  describe "launch/4" do
    test "sends the suite completion result to the recipient" do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})
      suite = suite_fixture(%{prompt_id: prompt.id})
      provider = provider_fixture()
      version = List.first(prompt.versions)

      assert {:ok, task_pid} = SuiteRunner.launch(self(), suite.id, version.id, provider.id)
      monitor_ref = Process.monitor(task_pid)

      assert_receive {:suite_completed, {:ok, suite_run}}, 1000
      assert suite_run.suite_id == suite.id
      assert_receive {:DOWN, ^monitor_ref, :process, ^task_pid, :normal}, 1000
    end

    test "sends an error result when dependent records cannot be loaded" do
      prompt = prompt_fixture_with_version(%{template: "Hello {{name}}"})
      suite = suite_fixture(%{prompt_id: prompt.id})
      version = List.first(prompt.versions)

      assert {:ok, task_pid} =
               SuiteRunner.launch(self(), suite.id, version.id, Ecto.UUID.generate())

      monitor_ref = Process.monitor(task_pid)

      assert_receive {:suite_completed, {:error, :provider_not_found}}, 1000
      assert_receive {:DOWN, ^monitor_ref, :process, ^task_pid, :normal}, 1000
    end
  end
end
