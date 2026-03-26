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
  end
end
