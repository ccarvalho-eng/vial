defmodule Vial.Repo.Migrations.AddCostLatencyToSuiteRuns do
  use Ecto.Migration

  def change do
    alter table(:suite_runs) do
      add :avg_cost_usd, :decimal, precision: 10, scale: 6
      add :avg_latency_ms, :integer
    end
  end
end
