defmodule Aludel.Stats.LatencyTest do
  use Aludel.DataCase

  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Aludel.RunsFixtures

  alias Aludel.Stats.Latency

  describe "latency_percentiles/0" do
    test "calculates P50 and P95 with multiple values" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()
      run = run_fixture(%{prompt_version_id: version.id})

      latencies = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]

      for latency <- latencies do
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider.id,
          latency_ms: latency
        })
      end

      percentiles = Latency.latency_percentiles()

      assert percentiles.p50 == 500.0
      assert percentiles.p95 == 1000.0
    end

    test "returns zero when no latency data" do
      percentiles = Latency.latency_percentiles()

      assert percentiles.p50 == 0
      assert percentiles.p95 == 0
    end

    test "returns latency breakdown by provider sorted by average latency" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      fast_provider = provider_fixture(%{name: "Fast Provider"})
      slow_provider = provider_fixture(%{name: "Slow Provider"})
      run = run_fixture(%{prompt_version_id: version.id})

      run_result_fixture(%{run_id: run.id, provider_id: slow_provider.id, latency_ms: 900})
      run_result_fixture(%{run_id: run.id, provider_id: slow_provider.id, latency_ms: 300})
      run_result_fixture(%{run_id: run.id, provider_id: fast_provider.id, latency_ms: 100})
      run_result_fixture(%{run_id: run.id, provider_id: fast_provider.id, latency_ms: 200})

      breakdown = Latency.latency_by_provider()

      assert [
               %{
                 provider_name: "Fast Provider",
                 avg_latency: 150.0,
                 min_latency: 100.0,
                 max_latency: 200.0,
                 run_count: 2
               },
               %{
                 provider_name: "Slow Provider",
                 avg_latency: 600.0,
                 min_latency: 300.0,
                 max_latency: 900.0,
                 run_count: 2
               }
             ] = breakdown
    end
  end
end
