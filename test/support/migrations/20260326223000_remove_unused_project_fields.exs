defmodule Aludel.Repo.Migrations.RemoveUnusedProjectFields do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :parent_id
      remove :position
    end

    drop_if_exists index(:projects, [:parent_id])
    drop_if_exists index(:projects, [:position])
  end
end
