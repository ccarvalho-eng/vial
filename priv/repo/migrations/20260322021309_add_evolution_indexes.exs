defmodule Vial.Repo.Migrations.AddEvolutionIndexes do
  use Ecto.Migration

  def change do
    create index(:suite_runs, [:prompt_version_id, :provider_id])
  end
end
