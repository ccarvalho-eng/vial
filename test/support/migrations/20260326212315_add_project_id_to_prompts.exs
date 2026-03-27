defmodule Aludel.Repo.Migrations.AddProjectIdToPrompts do
  use Ecto.Migration

  def change do
    alter table(:prompts) do
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:prompts, [:project_id])
  end
end
