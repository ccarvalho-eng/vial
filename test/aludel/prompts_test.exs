defmodule Aludel.PromptsTest do
  use Aludel.DataCase, async: true

  alias Aludel.Projects
  alias Aludel.Prompts

  describe "prompts" do
    test "create_prompt/1 creates a prompt with valid attributes" do
      attrs = %{
        name: "Test Prompt",
        description: "A test prompt",
        tags: ["test", "sample"]
      }

      assert {:ok, prompt} = Prompts.create_prompt(attrs)
      assert prompt.name == "Test Prompt"
      assert prompt.description == "A test prompt"
      assert prompt.tags == ["test", "sample"]
    end

    test "create_prompt/1 normalizes comma-separated tags string" do
      attrs = %{
        "name" => "Test Prompt",
        "tags" => "elixir, phoenix, testing"
      }

      assert {:ok, prompt} = Prompts.create_prompt(attrs)
      assert prompt.tags == ["elixir", "phoenix", "testing"]
    end

    test "create_prompt/1 trims whitespace from tags" do
      attrs = %{
        "name" => "Test Prompt",
        "tags" => "  elixir  ,  phoenix  ,  testing  "
      }

      assert {:ok, prompt} = Prompts.create_prompt(attrs)
      assert prompt.tags == ["elixir", "phoenix", "testing"]
    end

    test "create_prompt/1 rejects empty tags" do
      attrs = %{
        "name" => "Test Prompt",
        "tags" => "elixir, , phoenix, , testing"
      }

      assert {:ok, prompt} = Prompts.create_prompt(attrs)
      assert prompt.tags == ["elixir", "phoenix", "testing"]
    end

    test "update_prompt/2 normalizes comma-separated tags string" do
      prompt = prompt_fixture()

      attrs = %{"tags" => "updated, tags, list"}
      assert {:ok, updated} = Prompts.update_prompt(prompt, attrs)
      assert updated.tags == ["updated", "tags", "list"]
    end

    test "create_prompt/1 requires name" do
      attrs = %{description: "Test"}

      assert {:error, changeset} = Prompts.create_prompt(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "list_prompts/0 returns all prompts" do
      prompt = prompt_fixture()
      assert Prompts.list_prompts() == [prompt]
    end
  end

  describe "prompt_versions" do
    test "create_prompt_version/2 creates first version" do
      prompt = prompt_fixture()
      template = "Hello {{name}}, how are you?"

      assert {:ok, version} = Prompts.create_prompt_version(prompt, template)
      assert version.version == 1
      assert version.template == template
      assert version.variables == ["name"]
      assert version.prompt_id == prompt.id
    end

    test "create_prompt_version/2 auto-increments version number" do
      prompt = prompt_fixture()
      {:ok, v1} = Prompts.create_prompt_version(prompt, "Template 1 {{var}}")
      {:ok, v2} = Prompts.create_prompt_version(prompt, "Template 2 {{var}}")

      assert v1.version == 1
      assert v2.version == 2
    end

    test "extract_variables/1 parses template variables" do
      template = "Hello {{name}}, your score is {{score}} in {{subject}}"
      assert Prompts.extract_variables(template) == ["name", "score", "subject"]
    end

    test "extract_variables/1 handles templates with no variables" do
      template = "Hello world"
      assert Prompts.extract_variables(template) == []
    end

    test "extract_variables/1 removes duplicates" do
      template = "{{name}} {{name}} {{age}}"
      assert Prompts.extract_variables(template) == ["name", "age"]
    end
  end

  describe "evolution" do
    test "get_evolution_metrics/1 returns metrics for prompt" do
      prompt = prompt_fixture()
      {:ok, _version} = Prompts.create_prompt_version(prompt, "Test {{var}}")

      metrics = Prompts.get_evolution_metrics(prompt.id)

      assert is_list(metrics)
      assert length(metrics) == 1
    end
  end

  describe "projects" do
    test "create_project/1 creates a project with valid attributes" do
      attrs = %{name: "Customer Support"}

      assert {:ok, project} = Projects.create_project(attrs)
      assert project.name == "Customer Support"
    end

    test "create_project/1 requires name" do
      assert {:error, changeset} = Projects.create_project(%{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "list_projects/0 returns all projects ordered by creation" do
      {:ok, p1} = Projects.create_project(%{name: "Project A"})
      {:ok, p2} = Projects.create_project(%{name: "Project B"})

      projects = Projects.list_projects()
      assert length(projects) == 2
      assert Enum.at(projects, 0).id == p1.id
      assert Enum.at(projects, 1).id == p2.id
    end

    test "get_project!/1 returns project with given id" do
      {:ok, project} = Projects.create_project(%{name: "Test Project"})
      assert Projects.get_project!(project.id).name == "Test Project"
    end

    test "update_project/2 updates project" do
      {:ok, project} = Projects.create_project(%{name: "Old Name"})
      assert {:ok, updated} = Projects.update_project(project, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "delete_project/1 deletes project" do
      {:ok, project} = Projects.create_project(%{name: "To Delete"})
      assert {:ok, _} = Projects.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(project.id) end
    end
  end

  describe "pagination" do
    test "list_prompts/1 returns paginated results" do
      {:ok, project} = Projects.create_project(%{name: "Test"})

      for i <- 1..15 do
        Prompts.create_prompt(%{
          name: "Prompt #{i}",
          project_id: project.id
        })
      end

      page1 = Prompts.list_prompts(%{page: 1, page_size: 10})
      assert length(page1.entries) == 10
      assert page1.page_number == 1
      assert page1.total_entries == 15
      assert page1.total_pages == 2

      page2 = Prompts.list_prompts(%{page: 2, page_size: 10})
      assert length(page2.entries) == 5
      assert page2.page_number == 2
    end

    test "list_prompts/1 filters by project_id" do
      {:ok, project1} = Projects.create_project(%{name: "Project 1"})
      {:ok, project2} = Projects.create_project(%{name: "Project 2"})

      Prompts.create_prompt(%{name: "P1 Prompt", project_id: project1.id})
      Prompts.create_prompt(%{name: "P2 Prompt", project_id: project2.id})

      results = Prompts.list_prompts(%{project_id: project1.id})
      assert length(results.entries) == 1
      assert hd(results.entries).name == "P1 Prompt"
    end
  end
end
