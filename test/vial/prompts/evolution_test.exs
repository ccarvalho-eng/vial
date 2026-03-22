defmodule Vial.Prompts.EvolutionTest do
  use Vial.DataCase, async: true

  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures
  import Vial.EvalsFixtures

  alias Vial.Evals
  alias Vial.Prompts
  alias Vial.Prompts.Evolution

  describe "get_metrics/1" do
    test "returns empty list when prompt has no versions" do
      prompt = prompt_fixture()
      assert Evolution.get_metrics(prompt.id) == []
    end

    test "returns metrics for version with no suite runs" do
      prompt = prompt_fixture()
      {:ok, version} = Prompts.create_prompt_version(prompt, "Test {{var}}")

      metrics = Evolution.get_metrics(prompt.id)

      assert length(metrics) == 1
      assert [metric] = metrics
      assert metric.version_id == version.id
      assert metric.version_number == 1
      assert metric.total_runs == 0
      assert metric.avg_pass_rate == nil
      assert metric.avg_cost_usd == nil
      assert metric.avg_latency_ms == nil
      assert metric.provider_breakdown == []
    end

    test "calculates metrics for single version with suite runs" do
      prompt = prompt_fixture()
      provider = provider_fixture()
      {:ok, version} = Prompts.create_prompt_version(prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # Create suite runs with varying pass rates
      {:ok, _sr1} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 8,
          failed: 2
        })

      {:ok, _sr2} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(prompt.id)

      assert length(metrics) == 1
      assert [metric] = metrics
      assert metric.version_number == 1
      assert metric.total_runs == 2
      # (8+9) / (10+10) * 100 = 85.0
      assert metric.avg_pass_rate == 85.0
      assert length(metric.provider_breakdown) == 1

      [breakdown] = metric.provider_breakdown
      assert breakdown.provider_id == provider.id
      assert breakdown.runs == 2
      assert breakdown.avg_pass_rate == 85.0
    end

    test "tracks metrics across multiple versions" do
      prompt = prompt_fixture()
      provider = provider_fixture()
      {:ok, v1} = Prompts.create_prompt_version(prompt, "Version 1 {{var}}")
      {:ok, v2} = Prompts.create_prompt_version(prompt, "Version 2 {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # V1 with lower pass rate
      {:ok, _sr1} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: v1.id,
          provider_id: provider.id,
          passed: 6,
          failed: 4
        })

      # V2 with higher pass rate
      {:ok, _sr2} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: v2.id,
          provider_id: provider.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(prompt.id)

      assert length(metrics) == 2
      assert [m1, m2] = metrics

      # Verify ordering by version number
      assert m1.version_number == 1
      assert m2.version_number == 2

      # Verify pass rates show improvement
      assert m1.avg_pass_rate == 60.0
      assert m2.avg_pass_rate == 90.0
    end

    test "calculates provider breakdown for multiple providers" do
      prompt = prompt_fixture()
      p1 = provider_fixture(%{name: "Provider A"})
      p2 = provider_fixture(%{name: "Provider B"})
      {:ok, version} = Prompts.create_prompt_version(prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # Provider A: 80% pass rate
      {:ok, _sr1} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: p1.id,
          passed: 8,
          failed: 2
        })

      # Provider B: 90% pass rate
      {:ok, _sr2} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: p2.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(prompt.id)
      assert [metric] = metrics

      assert length(metric.provider_breakdown) == 2
      assert [b1, b2] = metric.provider_breakdown

      # Sorted by provider name
      assert b1.provider_name == "Provider A"
      assert b1.avg_pass_rate == 80.0
      assert b2.provider_name == "Provider B"
      assert b2.avg_pass_rate == 90.0
    end

    test "handles suite runs with zero tests" do
      prompt = prompt_fixture()
      provider = provider_fixture()
      {:ok, version} = Prompts.create_prompt_version(prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      {:ok, _sr} =
        Evals.create_suite_run(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 0,
          failed: 0
        })

      metrics = Evolution.get_metrics(prompt.id)
      assert [metric] = metrics
      assert metric.avg_pass_rate == nil
    end
  end
end
