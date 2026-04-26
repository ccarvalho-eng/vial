defmodule Aludel.Repo.Migrations.AddMetadataToRunResults do
  use Ecto.Migration

  def change do
    alter table(:run_results) do
      add :metadata, :map
    end
  end
end
