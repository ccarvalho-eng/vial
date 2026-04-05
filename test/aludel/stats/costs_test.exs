defmodule Aludel.Stats.CostsTest do
  use Aludel.DataCase

  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Aludel.RunsFixtures

  alias Aludel.Stats.Costs

  describe "cost_per_run/0" do
    test "calculates average cost per run" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()

      run1 = run_fixture(%{prompt_version_id: version.id})

      run_result_fixture(%{
        run_id: run1.id,
        provider_id: provider.id,
        cost_usd: 0.003
      })

      run2 = run_fixture(%{prompt_version_id: version.id})

      run_result_fixture(%{
        run_id: run2.id,
        provider_id: provider.id,
        cost_usd: 0.006
      })

      suite = suite_fixture()

      suite_run_fixture(%{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        avg_cost_usd: Decimal.new("0.009"),
        results: [
          %{"cost_usd" => 0.006, "latency_ms" => 100, "passed" => true},
          %{"cost_usd" => 0.012, "latency_ms" => 120, "passed" => true}
        ]
      })

      cost_per_run = Costs.cost_per_run()

      assert_in_delta cost_per_run, 0.009, 0.0001
    end

    test "returns zero when no runs exist" do
      cost_per_run = Costs.cost_per_run()

      assert cost_per_run == 0.0
    end

    test "aggregates costs by provider across runs and suite runs" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider1 = provider_fixture(%{name: "Provider A"})
      provider2 = provider_fixture(%{name: "Provider B"})

      run1 = run_fixture(%{prompt_version_id: version.id})
      run2 = run_fixture(%{prompt_version_id: version.id})

      run_result_fixture(%{run_id: run1.id, provider_id: provider1.id, cost_usd: 0.003})
      run_result_fixture(%{run_id: run2.id, provider_id: provider1.id, cost_usd: 0.007})
      run_result_fixture(%{run_id: run2.id, provider_id: provider2.id, cost_usd: 0.002})

      suite = suite_fixture()

      suite_run_fixture(%{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider1.id,
        avg_cost_usd: Decimal.new("0.010"),
        results: [
          %{"cost_usd" => 0.008, "latency_ms" => 100, "passed" => true},
          %{"cost_usd" => 0.012, "latency_ms" => 130, "passed" => false}
        ]
      })

      breakdown = Costs.cost_by_provider()

      assert [
               %{
                 provider_name: "Provider A",
                 total_cost: provider1_total,
                 run_count: 3,
                 avg_cost: provider1_avg
               },
               %{
                 provider_name: "Provider B",
                 total_cost: provider2_total,
                 run_count: 1,
                 avg_cost: provider2_avg
               }
             ] = breakdown

      assert_in_delta provider1_total, 0.030, 0.0001
      assert_in_delta provider1_avg, 0.030 / 3, 0.0001
      assert_in_delta provider2_total, 0.002, 0.0001
      assert_in_delta provider2_avg, 0.002, 0.0001
    end

    test "aggregates costs by prompt across runs and suite runs" do
      prompt1 = prompt_fixture(%{name: "Prompt A"})
      {:ok, version1} = Aludel.Prompts.create_prompt_version(prompt1, "Template A")
      prompt2 = prompt_fixture(%{name: "Prompt B"})
      {:ok, version2} = Aludel.Prompts.create_prompt_version(prompt2, "Template B")
      provider = provider_fixture()

      run1 = run_fixture(%{prompt_version_id: version1.id})
      run2 = run_fixture(%{prompt_version_id: version2.id})

      run_result_fixture(%{run_id: run1.id, provider_id: provider.id, cost_usd: 0.003})
      run_result_fixture(%{run_id: run2.id, provider_id: provider.id, cost_usd: 0.002})

      suite = suite_fixture()

      suite_run_fixture(%{
        suite_id: suite.id,
        prompt_version_id: version1.id,
        provider_id: provider.id,
        avg_cost_usd: Decimal.new("0.009"),
        results: [
          %{"cost_usd" => 0.005, "latency_ms" => 100, "passed" => true},
          %{"cost_usd" => 0.013, "latency_ms" => 120, "passed" => true}
        ]
      })

      breakdown = Costs.cost_by_prompt()

      assert [
               %{
                 prompt_name: "Prompt A",
                 total_cost: prompt1_total,
                 run_count: 2,
                 avg_cost: prompt1_avg
               },
               %{
                 prompt_name: "Prompt B",
                 total_cost: prompt2_total,
                 run_count: 1,
                 avg_cost: prompt2_avg
               }
             ] = breakdown

      assert_in_delta prompt1_total, 0.021, 0.0001
      assert_in_delta prompt1_avg, 0.0105, 0.0001
      assert_in_delta prompt2_total, 0.002, 0.0001
      assert_in_delta prompt2_avg, 0.002, 0.0001
    end
  end
end
