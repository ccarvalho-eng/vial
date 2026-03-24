defmodule Vial.Repo.Migrations.CreateTestCases do
  use Ecto.Migration

  def change do
    create table(:vial_test_cases, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :suite_id, references(:vial_suites, type: :binary_id, on_delete: :delete_all),
        null: false

      add :variable_values, :jsonb, null: false, default: "{}"
      add :assertions, :jsonb, null: false, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create index(:vial_test_cases, [:suite_id])
  end
end
