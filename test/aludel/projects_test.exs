defmodule Aludel.ProjectsTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals
  alias Aludel.Projects
  alias Aludel.Projects.Project
  alias Aludel.Prompts

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

    test "trims whitespace from name" do
      changeset = Project.changeset(%Project{}, %{name: "  Project Name  "})
      assert changeset.valid?
      assert get_change(changeset, :name) == "Project Name"
    end

    test "validates name length" do
      changeset = Project.changeset(%Project{}, %{name: String.duplicate("a", 256)})
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end

    test "rejects whitespace-only name" do
      changeset = Project.changeset(%Project{}, %{name: "   "})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "list_projects/0" do
    test "returns empty list when no projects exist" do
      assert Projects.list_projects() == []
    end

    test "returns projects with prompts and suites preloaded" do
      {:ok, project} = Projects.create_project(%{name: "Test Project"})

      {:ok, prompt} =
        Prompts.create_prompt(%{
          name: "Test Prompt",
          project_id: project.id
        })

      Prompts.create_prompt_version(prompt, "Hello {{name}}")

      {:ok, suite} =
        Evals.create_suite(%{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: project.id
        })

      [loaded_project] = Projects.list_projects()

      assert loaded_project.id == project.id
      assert loaded_project.name == "Test Project"
      assert Ecto.assoc_loaded?(loaded_project.prompts)
      assert Ecto.assoc_loaded?(loaded_project.suites)
      assert length(loaded_project.prompts) == 1
      assert length(loaded_project.suites) == 1
      assert hd(loaded_project.prompts).id == prompt.id

      loaded_suite = hd(loaded_project.suites)
      assert loaded_suite.id == suite.id
      assert Ecto.assoc_loaded?(loaded_suite.prompt)
      assert loaded_suite.prompt.id == prompt.id
    end

    test "preloads empty associations when project has no prompts or suites" do
      {:ok, project} = Projects.create_project(%{name: "Empty Project"})

      [loaded_project] = Projects.list_projects()

      assert loaded_project.id == project.id
      assert Ecto.assoc_loaded?(loaded_project.prompts)
      assert Ecto.assoc_loaded?(loaded_project.suites)
      assert loaded_project.prompts == []
      assert loaded_project.suites == []
    end
  end
end
