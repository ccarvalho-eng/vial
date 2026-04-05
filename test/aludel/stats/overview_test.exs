defmodule Aludel.Stats.OverviewTest do
  use Aludel.DataCase

  import Aludel.PromptsFixtures

  alias Aludel.Runs.Run
  alias Aludel.Stats.Overview

  describe "comparison_stats/1" do
    test "compares runs between current and previous periods" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")

      inserted_at_previous =
        DateTime.utc_now() |> DateTime.add(-10, :day) |> DateTime.truncate(:second)

      for _ <- 1..2 do
        %Run{}
        |> Run.changeset(%{
          name: "Previous Run",
          prompt_version_id: version.id,
          variable_values: %{}
        })
        |> Ecto.Changeset.put_change(:inserted_at, inserted_at_previous)
        |> Ecto.Changeset.put_change(:updated_at, inserted_at_previous)
        |> Repo.insert!()
      end

      inserted_at_current =
        DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)

      for _ <- 1..3 do
        %Run{}
        |> Run.changeset(%{
          name: "Current Run",
          prompt_version_id: version.id,
          variable_values: %{}
        })
        |> Ecto.Changeset.put_change(:inserted_at, inserted_at_current)
        |> Ecto.Changeset.put_change(:updated_at, inserted_at_current)
        |> Repo.insert!()
      end

      stats = Overview.comparison_stats(7)

      assert stats.previous.total_runs == 2
      assert stats.current.total_runs == 3
      assert stats.trends.total_runs == :up
    end

    test "returns stable trend when runs are equal" do
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template")

      inserted_at_previous =
        DateTime.utc_now() |> DateTime.add(-10, :day) |> DateTime.truncate(:second)

      %Run{}
      |> Run.changeset(%{
        name: "Previous Run",
        prompt_version_id: version.id,
        variable_values: %{}
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_previous)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_previous)
      |> Repo.insert!()

      inserted_at_current =
        DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)

      %Run{}
      |> Run.changeset(%{
        name: "Current Run",
        prompt_version_id: version.id,
        variable_values: %{}
      })
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at_current)
      |> Ecto.Changeset.put_change(:updated_at, inserted_at_current)
      |> Repo.insert!()

      stats = Overview.comparison_stats(7)

      assert stats.previous.total_runs == 1
      assert stats.current.total_runs == 1
      assert stats.trends.total_runs == :stable
    end
  end
end
