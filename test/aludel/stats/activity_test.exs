defmodule Aludel.Stats.ActivityTest do
  use Aludel.DataCase

  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Aludel.RunsFixtures

  alias Aludel.Evals.SuiteRun
  alias Aludel.Runs.Run
  alias Aludel.Stats.Activity

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

      normalized = Activity.normalize_suite_run(suite_run)

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

      normalized = Activity.normalize_suite_run(suite_run)

      assert normalized.cost == 0.0
    end
  end

  describe "daily_activity/1" do
    test "merges run and suite activity by day with zero-filled gaps" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()
      suite = suite_fixture(%{prompt_id: prompt.id})

      two_days_ago = Date.utc_today() |> Date.add(-2)
      one_day_ago = Date.utc_today() |> Date.add(-1)

      inserted_at_two_days_ago = DateTime.new!(two_days_ago, ~T[12:00:00], "Etc/UTC")
      inserted_at_one_day_ago = DateTime.new!(one_day_ago, ~T[12:00:00], "Etc/UTC")

      %Run{}
      |> Run.changeset(%{
        name: "Recent Run",
        prompt_version_id: version.id,
        variable_values: %{}
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_two_days_ago)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_two_days_ago)
      |> Repo.insert!()

      %SuiteRun{}
      |> SuiteRun.changeset(%{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        results: [],
        passed: 1,
        failed: 0
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_one_day_ago)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_one_day_ago)
      |> Repo.insert!()

      activity = Activity.daily_activity(3)

      assert %{date: ^two_days_ago, run_count: 1, suite_count: 0, total: 1} =
               Enum.find(activity, &(&1.date == two_days_ago))

      assert %{date: ^one_day_ago, run_count: 0, suite_count: 1, total: 1} =
               Enum.find(activity, &(&1.date == one_day_ago))
    end

    test "returns exactly the requested number of buckets including today" do
      activity = Activity.daily_activity(3)

      assert length(activity) == 3
      assert List.first(activity).date == Date.add(Date.utc_today(), -2)
      assert List.last(activity).date == Date.utc_today()
    end

    test "returns an empty list for non-positive day windows" do
      assert Activity.daily_activity(0) == []
      assert Activity.daily_activity(-1) == []
    end
  end

  describe "list_recent_activity/1" do
    test "combines normalized runs and suite runs in descending order and respects the limit" do
      prompt = prompt_fixture(%{name: "Prompt Name"})
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")
      provider = provider_fixture()
      suite = suite_fixture(%{name: "Suite Name", prompt_id: prompt.id})

      run =
        run_fixture(%{
          prompt_version_id: version.id,
          name: "Prompt Run"
        })

      run_result_fixture(%{
        run_id: run.id,
        provider_id: provider.id,
        cost_usd: 0.004
      })

      suite_run =
        suite_run_fixture(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          avg_cost_usd: Decimal.new("0.006"),
          passed: 2,
          failed: 1
        })

      newer = DateTime.utc_now() |> DateTime.truncate(:second)
      older = DateTime.add(newer, -60, :second)

      Repo.update_all(from(r in Run, where: r.id == ^run.id),
        set: [inserted_at: newer, updated_at: newer]
      )

      Repo.update_all(
        from(sr in SuiteRun, where: sr.id == ^suite_run.id),
        set: [inserted_at: older, updated_at: older]
      )

      activity = Activity.list_recent_activity(2)

      assert [
               %{
                 type: :run,
                 name: "Prompt Run",
                 prompt_name: "Prompt Name",
                 providers_count: 1,
                 cost: 0.004,
                 path: run_path
               },
               %{
                 type: :suite_run,
                 name: "Suite Name",
                 prompt_name: "Prompt Name",
                 providers_count: 1,
                 cost: 0.006,
                 passed: 2,
                 failed: 1,
                 path: suite_path
               }
             ] = activity

      assert run_path == "/runs/#{run.id}"
      assert suite_path == "/suites/#{suite.id}"
    end
  end
end
