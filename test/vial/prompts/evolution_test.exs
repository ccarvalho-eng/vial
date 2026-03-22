defmodule Vial.Prompts.EvolutionTest do
  use Vial.DataCase, async: true

  import Vial.PromptsFixtures

  alias Vial.Prompts.Evolution
  alias Vial.Prompts

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
      assert metric.total_suite_runs == 0
      assert metric.avg_pass_rate == nil
      assert metric.avg_cost_usd == nil
      assert metric.avg_latency_ms == nil
      assert metric.provider_breakdown == []
    end
  end
end
