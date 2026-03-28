defmodule Aludel.Repo.Migrations.CreateTestCaseDocuments do
  use Ecto.Migration

  def change do
    create table(:test_case_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :test_case_id, references(:test_cases, type: :binary_id, on_delete: :delete_all),
        null: false

      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :data, :binary, null: false
      add :size_bytes, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:test_case_documents, [:test_case_id])
  end
end
