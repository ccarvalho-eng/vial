defmodule Aludel.ProjectsTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals
  alias Aludel.Projects
  alias Aludel.Projects.Project
  alias Aludel.Prompts

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Project.changeset(%Project{}, %{name: "Customer Support", type: :prompt})
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Project.changeset(%Project{}, %{type: :prompt})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires type" do
      changeset = Project.changeset(%Project{}, %{name: "Customer Support"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
    end

    test "trims whitespace from name" do
      changeset = Project.changeset(%Project{}, %{name: "  Project Name  ", type: :prompt})
      assert changeset.valid?
      assert get_change(changeset, :name) == "Project Name"
    end

    test "validates name length" do
      changeset =
        Project.changeset(%Project{}, %{name: String.duplicate("a", 256), type: :prompt})

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end

    test "rejects whitespace-only name" do
      changeset = Project.changeset(%Project{}, %{name: "   ", type: :prompt})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "list_projects/0" do
    test "returns empty list when no projects exist" do
      assert Projects.list_projects() == []
    end

    test "returns prompt projects with prompts preloaded" do
      {:ok, project} = Projects.create_project(%{name: "Test Project", type: :prompt})

      {:ok, prompt} =
        Prompts.create_prompt(%{
          name: "Test Prompt",
          project_id: project.id
        })

      Prompts.create_prompt_version(prompt, "Hello {{name}}")

      {:ok, _suite} =
        Evals.create_suite(%{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: project.id
        })

      [loaded_project] = Projects.list_projects(type: :prompt)

      assert loaded_project.id == project.id
      assert loaded_project.name == "Test Project"
      assert Ecto.assoc_loaded?(loaded_project.prompts)
      assert length(loaded_project.prompts) == 1
      assert hd(loaded_project.prompts).id == prompt.id
      refute Ecto.assoc_loaded?(loaded_project.suites)
    end

    test "preloads empty associations when project has no prompts or suites" do
      {:ok, project} = Projects.create_project(%{name: "Empty Project", type: :prompt})

      [loaded_project] = Projects.list_projects(type: :prompt)

      assert loaded_project.id == project.id
      assert Ecto.assoc_loaded?(loaded_project.prompts)
      assert loaded_project.prompts == []
    end

    test "filters projects by type" do
      {:ok, prompt_project} = Projects.create_project(%{name: "Prompt Project", type: :prompt})
      {:ok, suite_project} = Projects.create_project(%{name: "Suite Project", type: :suite})

      assert [%{id: prompt_project_id}] = Projects.list_projects(type: :prompt)
      assert prompt_project_id == prompt_project.id

      assert [%{id: suite_project_id}] = Projects.list_projects(type: :suite)
      assert suite_project_id == suite_project.id
    end
  end
end
