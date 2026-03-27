defmodule Aludel.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :parent_id, references(:projects, type: :binary_id, on_delete: :delete_all)
      add :position, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:parent_id])
    create index(:projects, [:position])
  end
end
