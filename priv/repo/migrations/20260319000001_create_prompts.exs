defmodule Vial.Repo.Migrations.CreatePrompts do
  use Ecto.Migration

  def change do
    create table(:vial_prompts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:vial_prompts, [:tags], using: :gin)
  end
end
