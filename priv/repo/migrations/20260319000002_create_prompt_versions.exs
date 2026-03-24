defmodule Vial.Repo.Migrations.CreatePromptVersions do
  use Ecto.Migration

  def change do
    create table(:vial_prompt_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :prompt_id, references(:vial_prompts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :version, :integer, null: false
      add :template, :text, null: false
      add :variables, {:array, :string}, default: []

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:vial_prompt_versions, [:prompt_id])
    create unique_index(:vial_prompt_versions, [:prompt_id, :version])
  end
end
