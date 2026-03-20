defmodule Vial.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :prompt_version_id,
          references(:prompt_versions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string
      add :variable_values, :map, null: false, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create index(:runs, [:prompt_version_id])
  end
end
