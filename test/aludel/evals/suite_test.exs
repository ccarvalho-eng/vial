defmodule Aludel.Evals.SuiteTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals
  alias Aludel.Evals.Suite
  alias Aludel.Projects

  describe "changeset/2" do
    test "valid changeset with all fields" do
      prompt = prompt_fixture()

      changeset =
        Suite.changeset(%Suite{}, %{
          name: "Test Suite",
          prompt_id: prompt.id
        })

      assert changeset.valid?
    end

    test "valid changeset with project_id" do
      prompt = prompt_fixture()
      {:ok, project} = Projects.create_project(%{name: "Test Project", type: :suite})

      changeset =
        Suite.changeset(%Suite{}, %{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: project.id
        })

      assert changeset.valid?
    end

    test "requires name" do
      prompt = prompt_fixture()

      changeset = Suite.changeset(%Suite{}, %{prompt_id: prompt.id})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires prompt_id" do
      changeset = Suite.changeset(%Suite{}, %{name: "Test"})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).prompt_id
    end

    test "project_id is optional" do
      prompt = prompt_fixture()

      changeset =
        Suite.changeset(%Suite{}, %{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: nil
        })

      assert changeset.valid?
    end
  end

  describe "update with project_id" do
    test "can update suite project_id" do
      prompt = prompt_fixture()
      {:ok, project1} = Projects.create_project(%{name: "Project 1", type: :suite})
      {:ok, project2} = Projects.create_project(%{name: "Project 2", type: :suite})

      {:ok, suite} =
        Evals.create_suite(%{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: project1.id
        })

      assert suite.project_id == project1.id

      {:ok, updated_suite} = Evals.update_suite(suite, %{project_id: project2.id})

      assert updated_suite.project_id == project2.id
    end

    test "can set project_id to nil" do
      prompt = prompt_fixture()
      {:ok, project} = Projects.create_project(%{name: "Test Project", type: :suite})

      {:ok, suite} =
        Evals.create_suite(%{
          name: "Test Suite",
          prompt_id: prompt.id,
          project_id: project.id
        })

      assert suite.project_id == project.id

      {:ok, updated_suite} = Evals.update_suite(suite, %{project_id: nil})

      assert updated_suite.project_id == nil
    end
  end
end
