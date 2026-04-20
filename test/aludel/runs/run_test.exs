defmodule Aludel.Runs.RunTest do
  use Aludel.DataCase

  alias Aludel.Runs.Run

  import Aludel.PromptsFixtures

  describe "changeset/2" do
    setup do
      prompt = prompt_fixture()

      {:ok, version} =
        Aludel.Prompts.create_prompt_version(prompt, "Hello {{user}}")

      {:ok, prompt_version: version}
    end

    test "valid changeset with required fields", %{
      prompt_version: version
    } do
      changeset =
        Run.changeset(%Run{}, %{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Alice"}
        })

      assert changeset.valid?
    end

    test "valid changeset with name", %{prompt_version: version} do
      changeset =
        Run.changeset(%Run{}, %{
          prompt_version_id: version.id,
          name: "Test Run",
          variable_values: %{"user" => "Alice"}
        })

      assert changeset.valid?
      assert changeset.changes.name == "Test Run"
    end

    test "invalid changeset without prompt_version_id" do
      changeset =
        Run.changeset(%Run{}, %{
          variable_values: %{"user" => "Alice"}
        })

      refute changeset.valid?
      assert %{prompt_version_id: _} = errors_on(changeset)
    end

    test "invalid changeset without variable_values", %{
      prompt_version: version
    } do
      changeset =
        Run.changeset(%Run{}, %{
          prompt_version_id: version.id
        })

      refute changeset.valid?
      assert %{variable_values: _} = errors_on(changeset)
    end

    test "name is optional", %{prompt_version: version} do
      changeset =
        Run.changeset(%Run{}, %{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Alice"}
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :name)
    end

    test "public changeset ignores executor-managed fields", %{prompt_version: version} do
      changeset =
        Run.changeset(%Run{}, %{
          prompt_version_id: version.id,
          variable_values: %{"user" => "Alice"},
          status: :failed,
          started_at: ~U[2026-04-20 12:00:00Z],
          completed_at: ~U[2026-04-20 12:05:00Z],
          error_summary: "should not be accepted"
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :status)
      refute Map.has_key?(changeset.changes, :started_at)
      refute Map.has_key?(changeset.changes, :completed_at)
      refute Map.has_key?(changeset.changes, :error_summary)
    end

    test "execution_changeset casts lifecycle fields" do
      changeset =
        Run.execution_changeset(%Run{}, %{
          status: :running,
          started_at: ~U[2026-04-20 12:00:00Z],
          completed_at: ~U[2026-04-20 12:05:00Z],
          error_summary: "executor-owned"
        })

      assert changeset.valid?
      assert changeset.changes.status == :running
      assert changeset.changes.started_at == ~U[2026-04-20 12:00:00Z]
      assert changeset.changes.completed_at == ~U[2026-04-20 12:05:00Z]
      assert changeset.changes.error_summary == "executor-owned"
    end
  end
end
