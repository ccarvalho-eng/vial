defmodule Aludel.Test.Repo.Migrations.AddStorageFieldsToTestCaseDocuments do
  use Ecto.Migration

  def change do
    alter table(:test_case_documents) do
      add :storage_key, :string
      add :storage_backend, :string
      remove :data
    end

    create unique_index(:test_case_documents, [:storage_backend, :storage_key],
             where: "storage_key IS NOT NULL",
             name: :test_case_documents_storage_reference_index
           )

    create constraint(
             :test_case_documents,
             :test_case_documents_external_storage_required,
             check: "storage_key IS NOT NULL AND storage_backend IS NOT NULL"
           )
  end
end
