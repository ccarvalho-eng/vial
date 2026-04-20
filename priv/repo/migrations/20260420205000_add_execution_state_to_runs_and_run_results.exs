defmodule Aludel.Repo.Migrations.AddExecutionStateToRunsAndRunResults do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add :status, :string, null: false, default: "pending"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error_summary, :text
    end

    alter table(:run_results) do
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
    end
  end
end
