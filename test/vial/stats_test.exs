defmodule Vial.StatsTest do
  use Vial.DataCase

  import Vial.EvalsFixtures
  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures

  alias Vial.Stats

  describe "normalize_suite_run/1" do
    test "includes avg_cost_usd" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(Repo, prompt, "Template")
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
      {:ok, version} = Vial.Prompts.create_prompt_version(Repo, prompt, "Template")
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
