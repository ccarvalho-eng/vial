defmodule Aludel.Runs.ExecutorTest do
  use Aludel.DataCase

  import Mox

  alias Aludel.Interfaces.HttpClientMock
  alias Aludel.Runs.Execution
  alias Aludel.Runs.Executor

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
      assert execution.failures == []
      assert length(execution.provider_results) == 1
      assert hd(execution.provider_results).status == :completed
    end

    test "returns a partial failure when provider outcomes are mixed", %{run: run} do
      provider1 = provider_fixture(%{name: "Provider 1", model: "provider-1-model"})
      provider2 = provider_fixture(%{name: "Provider 2", model: "provider-2-model"})

      expect(HttpClientMock, :request, 2, fn provider_model, _prompt, _opts ->
        case provider_model do
          "openai:provider-1-model" -> {:ok, build_mock_response("Hello Alice", 5, 10)}
          "openai:provider-2-model" -> {:error, "API timeout"}
        end
      end)

      assert {:ok, %Execution{} = execution} = Executor.execute(run, [provider1, provider2])
      assert execution.status == :partial_failure
      assert length(execution.failures) == 1
      assert length(execution.provider_results) == 2
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
