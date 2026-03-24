defmodule Vial.Migrations do
  @moduledoc """
  Database migration helpers for embedded Vial installations.

  ## Usage

  In your Phoenix application, create a migration:

      mix ecto.gen.migration add_vial_tables

  Then in the generated migration file:

      defmodule MyApp.Repo.Migrations.AddVialTables do
        use Ecto.Migration

        def up do
          Vial.Migrations.up()
        end

        def down do
          Vial.Migrations.down()
        end
      end

  ## Options

  Both `up/1` and `down/1` accept these options:

    * `:prefix` - PostgreSQL schema prefix for tables (defaults to "public")
    * `:skip_indexes` - Skip creating indexes (useful if customizing)

  ## Custom Schema Example

  To install Vial tables in a separate schema:

      def up do
        execute "CREATE SCHEMA IF NOT EXISTS vial"
        Vial.Migrations.up(prefix: "vial")
      end

      def down do
        Vial.Migrations.down(prefix: "vial")
        execute "DROP SCHEMA IF EXISTS vial CASCADE"
      end
  """

  use Ecto.Migration

  @doc """
  Run all Vial migrations to create required tables.
  """
  def up(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")
    skip_indexes = Keyword.get(opts, :skip_indexes, false)

    # Create tables with vial_ prefix to avoid conflicts
    create_providers_table(prefix)
    create_prompts_table(prefix)
    create_prompt_versions_table(prefix)
    create_suites_table(prefix)
    create_test_cases_table(prefix)
    create_suite_runs_table(prefix)
    create_runs_table(prefix)
    create_run_results_table(prefix)

    unless skip_indexes do
      create_indexes(prefix)
    end
  end

  @doc """
  Rollback all Vial tables.
  """
  def down(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")

    # Drop tables in reverse order due to foreign key constraints
    drop_if_exists table(:vial_run_results, prefix: prefix)
    drop_if_exists table(:vial_runs, prefix: prefix)
    drop_if_exists table(:vial_suite_runs, prefix: prefix)
    drop_if_exists table(:vial_test_cases, prefix: prefix)
    drop_if_exists table(:vial_suites, prefix: prefix)
    drop_if_exists table(:vial_prompt_versions, prefix: prefix)
    drop_if_exists table(:vial_prompts, prefix: prefix)
    drop_if_exists table(:vial_providers, prefix: prefix)
  end

  # Private functions for creating each table

  defp create_providers_table(prefix) do
    create table(:vial_providers, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :base_url, :string
      add :api_version, :string
      add :default_model, :string
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:vial_providers, [:name], prefix: prefix)
  end

  defp create_prompts_table(prefix) do
    create table(:vial_prompts, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:vial_prompts, [:name], prefix: prefix)
  end

  defp create_prompt_versions_table(prefix) do
    create table(:vial_prompt_versions, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true

      add :prompt_id, references(:vial_prompts, on_delete: :delete_all, type: :binary_id),
        null: false

      add :version_number, :integer, null: false
      add :content, :text, null: false
      add :variables, {:array, :string}, default: []
      add :changelog, :text
      add :is_active, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:vial_prompt_versions, [:prompt_id, :version_number], prefix: prefix)
    create index(:vial_prompt_versions, [:prompt_id], prefix: prefix)
  end

  defp create_suites_table(prefix) do
    create table(:vial_suites, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:vial_suites, [:name], prefix: prefix)
  end

  defp create_test_cases_table(prefix) do
    create table(:vial_test_cases, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true

      add :suite_id, references(:vial_suites, on_delete: :delete_all, type: :binary_id),
        null: false

      add :name, :string, null: false
      add :description, :text
      add :input, :map, null: false
      add :expected_output, :text
      add :evaluation_criteria, :text
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:vial_test_cases, [:suite_id], prefix: prefix)
  end

  defp create_suite_runs_table(prefix) do
    create table(:vial_suite_runs, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true

      add :suite_id, references(:vial_suites, on_delete: :delete_all, type: :binary_id),
        null: false

      add :prompt_version_id,
          references(:vial_prompt_versions, on_delete: :nilify_all, type: :binary_id)

      add :provider_id, references(:vial_providers, on_delete: :nilify_all, type: :binary_id)
      add :status, :string, null: false, default: "pending"
      add :passed_count, :integer, default: 0
      add :failed_count, :integer, default: 0
      add :model, :string
      add :config, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error, :text
      add :total_cost, :decimal, precision: 10, scale: 6
      add :total_latency_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:vial_suite_runs, [:suite_id], prefix: prefix)
    create index(:vial_suite_runs, [:prompt_version_id], prefix: prefix)
    create index(:vial_suite_runs, [:provider_id], prefix: prefix)
  end

  defp create_runs_table(prefix) do
    create table(:vial_runs, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true

      add :prompt_version_id,
          references(:vial_prompt_versions, on_delete: :nilify_all, type: :binary_id)

      add :provider_id, references(:vial_providers, on_delete: :nilify_all, type: :binary_id)
      add :status, :string, null: false, default: "pending"
      add :model, :string
      add :config, :map, default: %{}
      add :variables, :map, default: %{}
      add :prompt_text, :text
      add :response, :text
      add :latency_ms, :integer
      add :input_tokens, :integer
      add :output_tokens, :integer
      add :cost, :decimal, precision: 10, scale: 6
      add :error, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:vial_runs, [:prompt_version_id], prefix: prefix)
    create index(:vial_runs, [:provider_id], prefix: prefix)
    create index(:vial_runs, [:status], prefix: prefix)
  end

  defp create_run_results_table(prefix) do
    create table(:vial_run_results, primary_key: false, prefix: prefix) do
      add :id, :binary_id, primary_key: true

      add :suite_run_id, references(:vial_suite_runs, on_delete: :delete_all, type: :binary_id),
        null: false

      add :test_case_id, references(:vial_test_cases, on_delete: :delete_all, type: :binary_id),
        null: false

      add :run_id, references(:vial_runs, on_delete: :delete_all, type: :binary_id), null: false
      add :passed, :boolean, null: false
      add :evaluation_result, :text
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:vial_run_results, [:suite_run_id], prefix: prefix)
    create index(:vial_run_results, [:test_case_id], prefix: prefix)
    create index(:vial_run_results, [:run_id], prefix: prefix)
  end

  defp create_indexes(prefix) do
    # Evolution indexes
    create index(:vial_runs, [:inserted_at], prefix: prefix)
    create index(:vial_runs, [:prompt_version_id, :status, :inserted_at], prefix: prefix)

    # Performance indexes
    create index(:vial_suite_runs, [:status], prefix: prefix)
    create index(:vial_suite_runs, [:inserted_at], prefix: prefix)
    create index(:vial_run_results, [:passed], prefix: prefix)
  end

  @doc """
  Check if Vial tables are already migrated.

  Returns `true` if all required tables exist, `false` otherwise.
  """
  def migrated?(repo, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "public")

    query = """
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = $1
      AND table_name LIKE 'vial_%'
    """

    case repo.query(query, [prefix]) do
      # We have 8 tables
      {:ok, %{rows: [[count]]}} -> count >= 8
      _ -> false
    end
  end
end
