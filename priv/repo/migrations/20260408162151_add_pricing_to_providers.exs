defmodule Aludel.Repo.Migrations.AddPricingToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :pricing, :map
    end
  end
end
