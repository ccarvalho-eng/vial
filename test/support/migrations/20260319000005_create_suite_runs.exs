defmodule Aludel.Repo.Migrations.CreateSuiteRuns do
  use Ecto.Migration

  def change do
    create table(:suite_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :suite_id, references(:suites, type: :binary_id, on_delete: :delete_all), null: false

      add :prompt_version_id,
          references(:prompt_versions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :results, :jsonb, null: false, default: "[]"
      add :passed, :integer, null: false, default: 0
      add :failed, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:suite_runs, [:suite_id])
    create index(:suite_runs, [:prompt_version_id])
    create index(:suite_runs, [:provider_id])
  end
end
