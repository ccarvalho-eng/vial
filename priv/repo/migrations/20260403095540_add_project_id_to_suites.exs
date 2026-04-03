defmodule Aludel.Repo.Migrations.AddProjectIdToSuites do
  use Ecto.Migration

  def change do
    alter table(:suites) do
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:suites, [:project_id])
  end
end
