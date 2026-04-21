defmodule Aludel.Runs.ExecutorTest do
  use Aludel.DataCase

  import Mox

  alias Aludel.Interfaces.HttpClientMock
  alias Aludel.Runs.{Execution, Executor, Run}

  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures

  setup :set_mox_global
  setup :verify_on_exit!

  describe "execute/2" do
    setup do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Hello {{user}}")

      {:ok, run} =
        Aludel.Runs.create_run(%{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Alice"}
        })

      {:ok, run: Repo.preload(run, :prompt_version)}
    end

    test "returns a successful execution with persisted provider results", %{run: run} do
      provider = provider_fixture()
      mock_response = build_mock_response("Hello Alice", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      assert {:ok, %Execution{} = execution} = Executor.execute(run, [provider])
      assert execution.status == :ok
      assert execution.run.status == :completed
      assert execution.run.started_at
      assert execution.run.completed_at
      assert execution.failures == []
      assert length(execution.provider_results) == 1
      assert hd(execution.provider_results).status == :completed
      assert hd(execution.provider_results).started_at
      assert hd(execution.provider_results).completed_at
    end

    test "rejects empty provider lists", %{run: run} do
      assert {:error, :empty_providers} = Executor.execute(run, [])
    end

    test "rejects runs with missing template variables", %{run: run} do
      {:ok, run} =
        Aludel.Runs.update_run(run, %{
          variable_values: %{}
        })

      assert {:error, {:missing_variables, ["user"]}} =
               Executor.execute(run, [provider_fixture()])
    end

    test "marks the run failed after transition-time validation errors", %{run: run} do
      {:ok, run} =
        Aludel.Runs.update_run(run, %{
          variable_values: %{}
        })

      assert {:error, {:missing_variables, ["user"]}} =
               Executor.execute(run, [provider_fixture()])

      persisted_run = Aludel.Runs.get_run!(run.id)
      assert persisted_run.status == :failed
      assert persisted_run.started_at
      assert persisted_run.completed_at
      assert persisted_run.error_summary =~ "missing_variables"
    end

    test "returns a partial failure when provider outcomes are mixed", %{run: run} do
      provider1 = provider_fixture(%{name: "Provider 1", model: "provider-1-model"})
      provider2 = provider_fixture(%{name: "Provider 2", model: "provider-2-model"})

      expect(HttpClientMock, :request, 2, fn provider_model, _prompt, _opts ->
        case provider_model do
          "openai:provider-1-model" -> {:ok, build_mock_response("Hello Alice", 5, 10)}
          "openai:provider-2-model" -> {:error, {:network_error, :timeout}}
        end
      end)

      assert {:ok, %Execution{} = execution} = Executor.execute(run, [provider1, provider2])
      assert execution.status == :partial_failure
      assert execution.run.status == :partial_failure
      assert execution.run.started_at
      assert execution.run.completed_at
      assert execution.run.error_summary =~ provider2.name
      assert length(execution.failures) == 1
      assert length(execution.provider_results) == 2
    end

    test "supports duplicate providers without pending-result key collisions", %{run: run} do
      provider =
        provider_fixture(%{name: "Duplicated Provider", model: "duplicate-provider-model"})

      expect(HttpClientMock, :request, 2, fn "openai:duplicate-provider-model", _prompt, _opts ->
        {:ok, build_mock_response("Hello Alice", 5, 10)}
      end)

      assert {:ok, %Execution{} = execution} = Executor.execute(run, [provider, provider])
      assert execution.status == :ok
      assert execution.run.status == :completed
      assert length(execution.provider_results) == 2
      assert Enum.all?(execution.provider_results, &(&1.provider_id == provider.id))
    end

    test "rejects runs that already left the pending state", %{run: run} do
      {:ok, _run} =
        run
        |> Run.execution_changeset(%{
          status: :running,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()

      assert {:error, :run_not_found} = Executor.execute(run, [provider_fixture()])
    end

    test "persists task exits in concurrent execution", %{run: run} do
      original_mode = Application.get_env(:aludel, :run_execution_mode)

      Application.put_env(:aludel, :run_execution_mode, :concurrent)

      on_exit(fn ->
        Application.put_env(:aludel, :run_execution_mode, original_mode)
      end)

      provider = provider_fixture(%{model: "provider-exit-model"})

      expect(HttpClientMock, :request, fn "openai:provider-exit-model", _prompt, _opts ->
        exit(:boom)
      end)

      Phoenix.PubSub.subscribe(Aludel.PubSub, "run:#{run.id}")

      assert {:ok, %Execution{} = execution} = Executor.execute(run, [provider])
      assert execution.status == :error
      assert execution.run.status == :failed
      assert execution.run.started_at
      assert execution.run.completed_at
      assert execution.run.error_summary =~ provider.name

      assert [%{provider_id: provider_id, provider_name: provider_name, reason: reason}] =
               execution.failures

      assert provider_id == provider.id
      assert provider_name == provider.name
      assert match?({:task_exit, _}, reason)

      assert_receive {:run_result_update, _result_id, :error, message}, 1000
      assert message =~ "task_exit"
      assert message =~ "boom"

      assert [result] = execution.provider_results
      assert result.status == :error
      assert result.started_at
      assert result.completed_at
      assert result.error =~ "task_exit"
      assert result.error =~ "boom"
    end
  end

  describe "launch/2" do
    test "rejects empty provider lists" do
      assert {:error, :empty_providers} = Executor.launch(%Aludel.Runs.Run{}, [])
    end
  end

  defp build_mock_response(text, input_tokens, output_tokens) do
    %{
      content: text,
      input_tokens: input_tokens,
      output_tokens: output_tokens
    }
  end
end
