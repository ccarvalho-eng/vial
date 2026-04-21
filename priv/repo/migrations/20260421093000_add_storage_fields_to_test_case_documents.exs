defmodule Aludel.Repo.Migrations.AddStorageFieldsToTestCaseDocuments do
  use Ecto.Migration

  def change do
    alter table(:test_case_documents) do
      add :storage_key, :string
      add :storage_backend, :string
      modify :data, :binary, null: true
    end

    create unique_index(:test_case_documents, [:storage_backend, :storage_key],
             where: "storage_key IS NOT NULL",
             name: :test_case_documents_storage_reference_index
           )

    create constraint(
             :test_case_documents,
             :test_case_documents_external_storage_required,
             check: "data IS NULL AND storage_key IS NOT NULL AND storage_backend IS NOT NULL"
           )
  end
end
