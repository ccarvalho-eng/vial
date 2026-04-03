defmodule Aludel.Repo.Migrations.AddProjectIdToSuitesAndTypeToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :type, :string, null: false
    end

    alter table(:suites) do
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:projects, [:type])
    create index(:suites, [:project_id])
  end
end
