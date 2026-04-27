defmodule Aludel.Repo.Migrations.AddAvgScoreToSuiteRuns do
  use Ecto.Migration

  def change do
    alter table(:suite_runs) do
      add :avg_score, :decimal
    end
  end
end
