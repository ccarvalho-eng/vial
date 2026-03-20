defmodule Vial.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    create table(:providers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :config, :map, null: false, default: "{}"

      timestamps(type: :utc_datetime)
    end
  end
end
