defmodule Aludel.Prompts.ProjectTest do
  use Aludel.DataCase, async: true

  alias Aludel.Prompts.Project

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Project.changeset(%Project{}, %{name: "Customer Support"})
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Project.changeset(%Project{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "accepts parent_id for nested projects" do
      parent_id = Ecto.UUID.generate()

      changeset =
        Project.changeset(%Project{}, %{
          name: "API v2",
          parent_id: parent_id
        })

      assert changeset.valid?
      assert get_change(changeset, :parent_id) == parent_id
    end

    test "accepts position for ordering" do
      changeset = Project.changeset(%Project{}, %{name: "Test", position: 5})
      assert changeset.valid?
      assert get_change(changeset, :position) == 5
    end

    test "defaults position to 0" do
      changeset = Project.changeset(%Project{}, %{name: "Test"})
      assert changeset.valid?
      assert get_field(changeset, :position) == 0
    end
  end
end
