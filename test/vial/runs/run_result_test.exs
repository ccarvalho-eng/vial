defmodule Vial.Runs.RunResultTest do
  use Vial.DataCase

  alias Vial.Runs.RunResult

  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures

  describe "changeset/2" do
    setup do
      prompt = prompt_fixture()

      {:ok, version} =
        Vial.Prompts.create_prompt_version(Repo, prompt, "Hello {{user}}")

      {:ok, run} =
        Vial.Runs.create_run(Repo, %{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Test"}
        })

      provider = provider_fixture()
      {:ok, run: run, provider: provider}
    end

    test "valid changeset with all required fields", %{
      run: run,
      provider: provider
    } do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "Hello world",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :completed
        })

      assert changeset.valid?
    end

    test "valid changeset with pending status", %{
      run: run,
      provider: provider
    } do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "",
          input_tokens: 0,
          output_tokens: 0,
          latency_ms: 0,
          cost_usd: 0.0,
          status: :pending
        })

      assert changeset.valid?
    end

    test "valid changeset with streaming status", %{
      run: run,
      provider: provider
    } do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "Partial",
          input_tokens: 10,
          output_tokens: 2,
          latency_ms: 200,
          cost_usd: 0.0005,
          status: :streaming
        })

      assert changeset.valid?
    end

    test "valid changeset with error status and error message", %{
      run: run,
      provider: provider
    } do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "",
          input_tokens: 10,
          output_tokens: 0,
          latency_ms: 500,
          cost_usd: 0.0,
          status: :error,
          error: "API request failed"
        })

      assert changeset.valid?
      assert changeset.changes.error == "API request failed"
    end

    test "invalid changeset without run_id", %{provider: provider} do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          provider_id: provider.id,
          output: "Test",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :completed
        })

      refute changeset.valid?
      assert %{run_id: _} = errors_on(changeset)
    end

    test "invalid changeset without provider_id", %{run: run} do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          output: "Test",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :completed
        })

      refute changeset.valid?
      assert %{provider_id: _} = errors_on(changeset)
    end

    test "invalid changeset without status", %{run: run, provider: provider} do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "Test",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001
        })

      refute changeset.valid?
      assert %{status: _} = errors_on(changeset)
    end

    test "invalid changeset with invalid status", %{
      run: run,
      provider: provider
    } do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "Test",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :invalid_status
        })

      refute changeset.valid?
      assert %{status: _} = errors_on(changeset)
    end

    test "error field is optional", %{run: run, provider: provider} do
      changeset =
        RunResult.changeset(%RunResult{}, %{
          run_id: run.id,
          provider_id: provider.id,
          output: "Test",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :completed
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :error)
    end
  end
end
