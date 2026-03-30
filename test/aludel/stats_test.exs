defmodule Aludel.StatsTest do
  use Aludel.DataCase

  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Aludel.RunsFixtures

  alias Aludel.Stats

  describe "latency_percentiles/0" do
    test "calculates P50 and P95 with multiple values" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()
      run = run_fixture(%{prompt_version_id: version.id})

      # Create run results with varying latencies
      latencies = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]

      for latency <- latencies do
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider.id,
          latency_ms: latency
        })
      end

      percentiles = Stats.latency_percentiles()

      # With 10 values [100..1000]:
      # percentile_disc(0.5) returns 500 (50th percentile)
      # percentile_disc(0.95) returns 1000 (95th percentile)
      # Note: percentile_disc picks the first value at or above the percentile
      assert percentiles.p50 == 500.0
      assert percentiles.p95 == 1000.0
    end

    test "returns zero when no latency data" do
      percentiles = Stats.latency_percentiles()

      assert percentiles.p50 == 0
      assert percentiles.p95 == 0
    end
  end

  describe "cost_per_run/0" do
    test "calculates average cost per run" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()

      # Create 3 runs with known costs
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
        avg_cost_usd: Decimal.new("0.009")
      })

      # Total cost: 0.003 + 0.006 + 0.009 = 0.018
      # Total runs: 3 (2 prompt runs + 1 suite run)
      # Expected: 0.018 / 3 = 0.006

      cost_per_run = Stats.cost_per_run()

      assert_in_delta cost_per_run, 0.006, 0.0001
    end

    test "returns zero when no runs exist" do
      cost_per_run = Stats.cost_per_run()

      assert cost_per_run == 0.0
    end
  end

  describe "comparison_stats/1" do
    test "compares runs between current and previous periods" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")

      # Create runs in previous period (8-14 days ago)
      inserted_at_previous =
        DateTime.utc_now() |> DateTime.add(-10, :day) |> DateTime.truncate(:second)

      for _ <- 1..2 do
        %Aludel.Runs.Run{}
        |> Aludel.Runs.Run.changeset(%{
          name: "Previous Run",
          prompt_version_id: version.id,
          variable_values: %{}
        })
        |> Ecto.Changeset.put_change(:inserted_at, inserted_at_previous)
        |> Ecto.Changeset.put_change(:updated_at, inserted_at_previous)
        |> Repo.insert!()
      end

      # Create runs in current period (1-7 days ago)
      inserted_at_current =
        DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)

      for _ <- 1..3 do
        %Aludel.Runs.Run{}
        |> Aludel.Runs.Run.changeset(%{
          name: "Current Run",
          prompt_version_id: version.id,
          variable_values: %{}
        })
        |> Ecto.Changeset.put_change(:inserted_at, inserted_at_current)
        |> Ecto.Changeset.put_change(:updated_at, inserted_at_current)
        |> Repo.insert!()
      end

      stats = Stats.comparison_stats(7)

      assert stats.previous.total_runs == 2
      assert stats.current.total_runs == 3
      assert stats.trends.total_runs == :up
    end

    test "returns stable trend when runs are equal" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")

      inserted_at_previous =
        DateTime.utc_now() |> DateTime.add(-10, :day) |> DateTime.truncate(:second)

      %Aludel.Runs.Run{}
      |> Aludel.Runs.Run.changeset(%{
        name: "Previous Run",
        prompt_version_id: version.id,
        variable_values: %{}
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_previous)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_previous)
      |> Repo.insert!()

      inserted_at_current =
        DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)

      %Aludel.Runs.Run{}
      |> Aludel.Runs.Run.changeset(%{
        name: "Current Run",
        prompt_version_id: version.id,
        variable_values: %{}
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_current)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_current)
      |> Repo.insert!()

      stats = Stats.comparison_stats(7)

      assert stats.previous.total_runs == 1
      assert stats.current.total_runs == 1
      assert stats.trends.total_runs == :stable
    end
  end

  describe "normalize_suite_run/1" do
    test "includes avg_cost_usd" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()

      suite_run =
        suite_run_fixture(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          avg_cost_usd: Decimal.new("0.0042"),
          avg_latency_ms: 350
        })

      suite_run =
        Repo.preload(suite_run, [
          :suite,
          [prompt_version: :prompt],
          :provider
        ])

      normalized = Stats.normalize_suite_run(suite_run)

      assert normalized.cost == Decimal.to_float(Decimal.new("0.0042"))
    end

    test "handles nil cost" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()

      suite_run =
        suite_run_fixture(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          avg_cost_usd: nil,
          avg_latency_ms: nil
        })

      suite_run =
        Repo.preload(suite_run, [
          :suite,
          [prompt_version: :prompt],
          :provider
        ])

      normalized = Stats.normalize_suite_run(suite_run)

      assert normalized.cost == 0.0
    end
  end
end
