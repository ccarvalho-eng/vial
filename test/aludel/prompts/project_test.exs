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
  end
end
