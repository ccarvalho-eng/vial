defmodule Aludel.Repo.Migrations.CreateRunResults do
  use Ecto.Migration

  def change do
    create table(:run_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:runs, type: :binary_id, on_delete: :delete_all), null: false

      add :provider_id,
          references(:providers, type: :binary_id, on_delete: :delete_all),
          null: false

      add :output, :text
      add :input_tokens, :integer
      add :output_tokens, :integer
      add :latency_ms, :integer
      add :cost_usd, :float
      add :status, :string, null: false
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:run_results, [:run_id])
    create index(:run_results, [:provider_id])
  end
end
