defmodule Vial.Repo.Migrations.CreateSuites do
  use Ecto.Migration

  def change do
    create table(:vial_suites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      add :prompt_id, references(:vial_prompts, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:vial_suites, [:prompt_id])
  end
end
