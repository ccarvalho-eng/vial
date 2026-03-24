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
      assert Evolution.get_metrics(Repo, prompt.id) == []
    end

    test "returns metrics for version with no suite runs" do
      prompt = prompt_fixture()
      {:ok, version} = Prompts.create_prompt_version(Repo, prompt, "Test {{var}}")

      metrics = Evolution.get_metrics(Repo, prompt.id)

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
      {:ok, version} = Prompts.create_prompt_version(Repo, prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # Create suite runs with varying pass rates
      {:ok, _sr1} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 8,
          failed: 2
        })

      {:ok, _sr2} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(Repo, prompt.id)

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
      {:ok, v1} = Prompts.create_prompt_version(Repo, prompt, "Version 1 {{var}}")
      {:ok, v2} = Prompts.create_prompt_version(Repo, prompt, "Version 2 {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # V1 with lower pass rate
      {:ok, _sr1} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: v1.id,
          provider_id: provider.id,
          passed: 6,
          failed: 4
        })

      # V2 with higher pass rate
      {:ok, _sr2} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: v2.id,
          provider_id: provider.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(Repo, prompt.id)

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
      {:ok, version} = Prompts.create_prompt_version(Repo, prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      # Provider A: 80% pass rate
      {:ok, _sr1} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: p1.id,
          passed: 8,
          failed: 2
        })

      # Provider B: 90% pass rate
      {:ok, _sr2} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: p2.id,
          passed: 9,
          failed: 1
        })

      metrics = Evolution.get_metrics(Repo, prompt.id)
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
      {:ok, version} = Prompts.create_prompt_version(Repo, prompt, "Test {{var}}")
      suite = suite_fixture(%{prompt_id: prompt.id})

      {:ok, _sr} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 0,
          failed: 0
        })

      metrics = Evolution.get_metrics(Repo, prompt.id)
      assert [metric] = metrics
      assert metric.avg_pass_rate == nil
    end

    test "provider breakdown includes cost and latency" do
      prompt = prompt_fixture()
      {:ok, version} = Prompts.create_prompt_version(Repo, prompt, "Test {{var}}")
      provider1 = provider_fixture(%{name: "OpenAI"})
      provider2 = provider_fixture(%{name: "Anthropic"})
      suite = suite_fixture(%{prompt_id: prompt.id})

      {:ok, _sr1} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider1.id,
          passed: 5,
          failed: 0,
          avg_cost_usd: Decimal.new("0.004"),
          avg_latency_ms: 350
        })

      {:ok, _sr2} =
        Evals.create_suite_run(Repo, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider2.id,
          passed: 5,
          failed: 0,
          avg_cost_usd: Decimal.new("0.006"),
          avg_latency_ms: 420
        })

      [metrics] = Evolution.get_metrics(Repo, prompt.id)

      assert length(metrics.provider_breakdown) == 2

      openai = Enum.find(metrics.provider_breakdown, &(&1.provider_name == "OpenAI"))
      assert Decimal.equal?(openai.avg_cost_usd, Decimal.new("0.004"))
      assert openai.avg_latency_ms == 350

      anthropic = Enum.find(metrics.provider_breakdown, &(&1.provider_name == "Anthropic"))
      assert Decimal.equal?(anthropic.avg_cost_usd, Decimal.new("0.006"))
      assert anthropic.avg_latency_ms == 420
    end
  end

  describe "calculate_avg_cost from suite_runs" do
    test "returns nil for empty list" do
      assert Evolution.calculate_avg_cost([]) == nil
    end

    test "returns nil when all costs are nil" do
      suite_runs = [
        %{avg_cost_usd: nil},
        %{avg_cost_usd: nil}
      ]

      assert Evolution.calculate_avg_cost(suite_runs) == nil
    end

    test "averages non-nil costs only" do
      suite_runs = [
        %{avg_cost_usd: Decimal.new("0.004")},
        %{avg_cost_usd: nil},
        %{avg_cost_usd: Decimal.new("0.006")}
      ]

      result = Evolution.calculate_avg_cost(suite_runs)
      assert Decimal.equal?(result, Decimal.new("0.005"))
    end

    test "calculates average correctly" do
      suite_runs = [
        %{avg_cost_usd: Decimal.new("0.004")},
        %{avg_cost_usd: Decimal.new("0.006")},
        %{avg_cost_usd: Decimal.new("0.005")}
      ]

      result = Evolution.calculate_avg_cost(suite_runs)
      assert Decimal.equal?(result, Decimal.new("0.005"))
    end
  end

  describe "calculate_avg_latency from suite_runs" do
    test "returns nil for empty list" do
      assert Evolution.calculate_avg_latency([]) == nil
    end

    test "returns nil when all latencies are nil" do
      suite_runs = [
        %{avg_latency_ms: nil},
        %{avg_latency_ms: nil}
      ]

      assert Evolution.calculate_avg_latency(suite_runs) == nil
    end

    test "averages non-nil latencies only" do
      suite_runs = [
        %{avg_latency_ms: 400},
        %{avg_latency_ms: nil},
        %{avg_latency_ms: 600}
      ]

      assert Evolution.calculate_avg_latency(suite_runs) == 500
    end

    test "rounds to nearest integer" do
      suite_runs = [
        %{avg_latency_ms: 350},
        %{avg_latency_ms: 420},
        %{avg_latency_ms: 390}
      ]

      # (350 + 420 + 390) / 3 = 386.67 -> 387
      assert Evolution.calculate_avg_latency(suite_runs) == 387
    end
  end

  describe "prepare_chart_data/1" do
    test "transforms metrics into chart-ready structure" do
      metrics = [
        %{
          version_number: 1,
          avg_pass_rate: 78.5,
          avg_cost_usd: 0.021,
          avg_latency_ms: 480,
          provider_breakdown: [
            %{
              provider_name: "OpenAI",
              avg_pass_rate: 80.0,
              avg_cost_usd: 0.020,
              avg_latency_ms: 450
            },
            %{
              provider_name: "Anthropic",
              avg_pass_rate: 77.0,
              avg_cost_usd: 0.022,
              avg_latency_ms: 510
            }
          ]
        },
        %{
          version_number: 2,
          avg_pass_rate: 85.2,
          avg_cost_usd: 0.019,
          avg_latency_ms: 420,
          provider_breakdown: [
            %{
              provider_name: "OpenAI",
              avg_pass_rate: 87.0,
              avg_cost_usd: 0.018,
              avg_latency_ms: 400
            },
            %{
              provider_name: "Anthropic",
              avg_pass_rate: 83.5,
              avg_cost_usd: 0.020,
              avg_latency_ms: 440
            }
          ]
        }
      ]

      result = Evolution.prepare_chart_data(metrics)

      assert result.versions == [1, 2]
      assert result.overall.pass_rates == [78.5, 85.2]
      assert result.overall.costs == [0.021, 0.019]
      assert result.overall.latencies == [480, 420]
      assert result.by_provider["OpenAI"].pass_rates == [80.0, 87.0]
      assert result.by_provider["OpenAI"].costs == [0.020, 0.018]
      assert result.by_provider["OpenAI"].latencies == [450, 400]
      assert result.by_provider["Anthropic"].pass_rates == [77.0, 83.5]
      assert result.by_provider["Anthropic"].costs == [0.022, 0.020]
      assert result.by_provider["Anthropic"].latencies == [510, 440]
    end

    test "handles nil values gracefully" do
      metrics = [
        %{
          version_number: 1,
          avg_pass_rate: nil,
          avg_cost_usd: nil,
          avg_latency_ms: nil,
          provider_breakdown: []
        },
        %{
          version_number: 2,
          avg_pass_rate: 85.2,
          avg_cost_usd: 0.019,
          avg_latency_ms: 420,
          provider_breakdown: []
        }
      ]

      result = Evolution.prepare_chart_data(metrics)

      assert result.versions == [1, 2]
      assert result.overall.pass_rates == [nil, 85.2]
      assert result.overall.costs == [nil, 0.019]
      assert result.overall.latencies == [nil, 420]
      assert result.by_provider == %{}
    end

    test "handles empty metrics list" do
      result = Evolution.prepare_chart_data([])

      assert result.versions == []
      assert result.overall.pass_rates == []
      assert result.overall.costs == []
      assert result.overall.latencies == []
      assert result.by_provider == %{}
    end
  end
end
