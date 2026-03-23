defmodule Vial.RunsTest do
  use Vial.DataCase

  alias Vial.Runs

  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures

  describe "runs" do
    alias Vial.Runs.Run

    @valid_attrs %{
      name: "Test Run",
      variable_values: %{"user" => "Alice", "topic" => "AI"}
    }
    @update_attrs %{
      name: "Updated Run",
      variable_values: %{"user" => "Bob", "topic" => "ML"}
    }
    @invalid_attrs %{prompt_version_id: nil}

    setup do
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Hello {{user}}")
      {:ok, prompt_version: version}
    end

    test "total_cost/0 includes suite run costs" do
      import Vial.EvalsFixtures

      # Create a run result with cost
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()

      {:ok, run} =
        Runs.create_run(%{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Test"}
        })

      {:ok, _result} =
        Runs.create_run_result(%{
          run_id: run.id,
          provider_id: provider.id,
          output: "Output",
          cost_usd: 0.001,
          status: :completed
        })

      # Create a suite run with cost
      _suite_run =
        suite_run_fixture(%{
          avg_cost_usd: Decimal.new("0.005")
        })

      total = Runs.total_cost()

      # Should include both run result cost (0.001) and suite run cost (0.005)
      assert_in_delta total, 0.006, 0.0001
    end

    test "list_runs/0 returns all runs", %{prompt_version: version} do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      assert Runs.list_runs() == [run]
    end

    test "get_run!/1 returns the run with given id", %{prompt_version: version} do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      assert Runs.get_run!(run.id).id == run.id
    end

    test "get_run!/1 preloads run_results and providers", %{
      prompt_version: version
    } do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      provider = provider_fixture()

      {:ok, _result} =
        Runs.create_run_result(%{
          run_id: run.id,
          provider_id: provider.id,
          output: "Hello Alice",
          input_tokens: 10,
          output_tokens: 5,
          latency_ms: 500,
          cost_usd: 0.001,
          status: :completed
        })

      loaded_run = Runs.get_run!(run.id)
      assert Ecto.assoc_loaded?(loaded_run.run_results)
      assert length(loaded_run.run_results) == 1
      assert Ecto.assoc_loaded?(hd(loaded_run.run_results).provider)
    end

    test "create_run/1 with valid data creates a run", %{
      prompt_version: version
    } do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      assert {:ok, %Run{} = run} = Runs.create_run(attrs)
      assert run.name == "Test Run"
      assert run.variable_values == %{"user" => "Alice", "topic" => "AI"}
      assert run.prompt_version_id == version.id
    end

    test "create_run/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Runs.create_run(@invalid_attrs)
    end

    test "update_run/2 with valid data updates the run", %{
      prompt_version: version
    } do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      assert {:ok, %Run{} = run} = Runs.update_run(run, @update_attrs)
      assert run.name == "Updated Run"
      assert run.variable_values == %{"user" => "Bob", "topic" => "ML"}
    end

    test "update_run/2 with invalid data returns error changeset", %{
      prompt_version: version
    } do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)

      assert {:error, %Ecto.Changeset{}} =
               Runs.update_run(run, @invalid_attrs)

      assert run.id == Runs.get_run!(run.id).id
    end

    test "delete_run/1 deletes the run", %{prompt_version: version} do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      assert {:ok, %Run{}} = Runs.delete_run(run)
      assert_raise Ecto.NoResultsError, fn -> Runs.get_run!(run.id) end
    end

    test "change_run/1 returns a run changeset", %{prompt_version: version} do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      assert %Ecto.Changeset{} = Runs.change_run(run)
    end

    test "change_run/2 returns a run changeset with attrs", %{
      prompt_version: version
    } do
      attrs = Map.put(@valid_attrs, :prompt_version_id, version.id)
      {:ok, run} = Runs.create_run(attrs)
      changeset = Runs.change_run(run, @update_attrs)
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.name == "Updated Run"
    end
  end

  describe "run_results" do
    alias Vial.Runs.RunResult

    @valid_result_attrs %{
      output: "Hello world",
      input_tokens: 10,
      output_tokens: 5,
      latency_ms: 500,
      cost_usd: 0.001,
      status: :completed
    }
    @update_result_attrs %{
      output: "Updated output",
      input_tokens: 15,
      output_tokens: 10,
      latency_ms: 750,
      cost_usd: 0.002,
      status: :error,
      error: "API error"
    }
    @invalid_result_attrs %{run_id: nil, provider_id: nil}

    setup do
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Hello {{user}}")

      {:ok, run} =
        Runs.create_run(%{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Test"}
        })

      provider = provider_fixture()
      {:ok, run: run, provider: provider}
    end

    test "create_run_result/1 with valid data creates a run_result", %{
      run: run,
      provider: provider
    } do
      attrs =
        @valid_result_attrs
        |> Map.put(:run_id, run.id)
        |> Map.put(:provider_id, provider.id)

      assert {:ok, %RunResult{} = result} = Runs.create_run_result(attrs)
      assert result.output == "Hello world"
      assert result.input_tokens == 10
      assert result.output_tokens == 5
      assert result.latency_ms == 500
      assert result.cost_usd == 0.001
      assert result.status == :completed
    end

    test "create_run_result/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Runs.create_run_result(@invalid_result_attrs)
    end

    test "update_run_result/2 with valid data updates the run_result", %{
      run: run,
      provider: provider
    } do
      attrs =
        @valid_result_attrs
        |> Map.put(:run_id, run.id)
        |> Map.put(:provider_id, provider.id)

      {:ok, result} = Runs.create_run_result(attrs)

      assert {:ok, %RunResult{} = result} =
               Runs.update_run_result(result, @update_result_attrs)

      assert result.output == "Updated output"
      assert result.input_tokens == 15
      assert result.status == :error
      assert result.error == "API error"
    end

    test "update_run_result/2 with invalid data returns error changeset", %{
      run: run,
      provider: provider
    } do
      attrs =
        @valid_result_attrs
        |> Map.put(:run_id, run.id)
        |> Map.put(:provider_id, provider.id)

      {:ok, result} = Runs.create_run_result(attrs)

      assert {:error, %Ecto.Changeset{}} =
               Runs.update_run_result(result, @invalid_result_attrs)
    end
  end

  describe "execute_run/2" do
    setup do
      prompt = prompt_fixture()

      {:ok, version} =
        Vial.Prompts.create_prompt_version(prompt, "Hello {{user}}")

      {:ok, run} =
        Runs.create_run(%{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Alice"}
        })

      provider = provider_fixture()
      {:ok, run: run, provider: provider, prompt_version: version}
    end

    @tag :openai_integration
    test "executes run with single provider", %{
      run: run,
      provider: provider
    } do
      run = Vial.Repo.preload(run, :prompt_version)
      assert {:ok, result_run} = Runs.execute_run(run, [provider])

      assert Ecto.assoc_loaded?(result_run.run_results)
      assert length(result_run.run_results) == 1

      result = hd(result_run.run_results)
      assert result.provider_id == provider.id
      assert result.status == :completed
      assert is_binary(result.output)
      assert result.input_tokens > 0
      assert result.output_tokens > 0
      assert result.latency_ms > 0
    end

    @tag :openai_integration
    test "executes run with multiple providers concurrently", %{
      run: run,
      provider: provider1
    } do
      provider2 = provider_fixture(%{name: "Provider 2"})
      provider3 = provider_fixture(%{name: "Provider 3"})

      run = Vial.Repo.preload(run, :prompt_version)

      assert {:ok, result_run} =
               Runs.execute_run(run, [provider1, provider2, provider3])

      assert Ecto.assoc_loaded?(result_run.run_results)
      assert length(result_run.run_results) == 3

      provider_ids =
        Enum.map(result_run.run_results, & &1.provider_id) |> Enum.sort()

      expected_ids = [provider1.id, provider2.id, provider3.id] |> Enum.sort()
      assert provider_ids == expected_ids

      for result <- result_run.run_results do
        assert result.status == :completed
        assert is_binary(result.output)
      end
    end

    @tag :openai_integration
    test "broadcasts PubSub updates during execution", %{
      run: run,
      provider: provider
    } do
      Phoenix.PubSub.subscribe(Vial.PubSub, "run:#{run.id}")

      run = Vial.Repo.preload(run, :prompt_version)
      assert {:ok, _result_run} = Runs.execute_run(run, [provider])

      # Should receive at least one update message
      assert_receive {:run_result_update, _result_id, :completed, _output},
                     1000
    end

    @tag :openai_integration
    test "renders template with variable values", %{
      run: run,
      provider: provider
    } do
      run = Vial.Repo.preload(run, :prompt_version)
      assert {:ok, result_run} = Runs.execute_run(run, [provider])

      result = hd(result_run.run_results)
      # The rendered prompt should contain "Hello Alice"
      assert result.output =~ "Hello Alice"
    end

    test "handles LLM errors gracefully", %{prompt_version: version} do
      # Create a provider that will cause an error
      # (We'll need to mock this in implementation)
      provider = provider_fixture(%{name: "Error Provider"})

      {:ok, run} =
        Runs.create_run(%{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Test"}
        })

      run = Vial.Repo.preload(run, :prompt_version)

      # For now, this should still succeed but handle errors per-provider
      assert {:ok, _result_run} = Runs.execute_run(run, [provider])
    end
  end
end
