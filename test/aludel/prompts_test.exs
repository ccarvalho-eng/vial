defmodule Aludel.PromptsTest do
  use Aludel.DataCase, async: true

  alias Aludel.Projects
  alias Aludel.Prompts
  alias Aludel.Prompts.PromptVersion

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

    test "list_prompts/1 applies search and tag filters" do
      match =
        prompt_fixture(%{
          name: "Alpha Prompt",
          description: "Relevant result",
          tags: ["alpha", "shared"]
        })

      later_match =
        prompt_fixture(%{
          name: "Another Alpha Prompt",
          description: "Also relevant",
          tags: ["alpha"]
        })

      _non_match =
        prompt_fixture(%{
          name: "Gamma Prompt",
          description: "Unrelated result",
          tags: ["gamma"]
        })

      results =
        Prompts.list_prompts(%{
          search: "alpha",
          tags: ["alpha"]
        })

      assert results
             |> Enum.map(& &1.id)
             |> Enum.sort() == Enum.sort([later_match.id, match.id])
    end

    test "create_prompt_with_initial_version/1 creates prompt and initial version" do
      attrs = %{
        "name" => "Versioned Prompt",
        "description" => "With initial template",
        "tags" => "elixir, test",
        "template" => "Hello {{name}}"
      }

      assert {:ok, prompt} = Prompts.create_prompt_with_initial_version(attrs)

      prompt = Prompts.get_prompt_with_versions!(prompt.id)
      assert prompt.name == "Versioned Prompt"
      assert prompt.tags == ["elixir", "test"]
      assert length(prompt.versions) == 1

      version = List.first(prompt.versions)
      assert version.version == 1
      assert version.template == "Hello {{name}}"
      assert version.variables == ["name"]
    end

    test "create_prompt_with_initial_version/1 creates only prompt when template is blank" do
      assert {:ok, prompt} =
               Prompts.create_prompt_with_initial_version(%{
                 "name" => "Prompt Without Version",
                 "template" => ""
               })

      prompt = Prompts.get_prompt_with_versions!(prompt.id)
      assert prompt.versions == []
    end

    test "create_prompt_with_initial_version/1 treats nil template as blank" do
      assert {:ok, prompt} =
               Prompts.create_prompt_with_initial_version(%{
                 "name" => "Nil Template Prompt",
                 "template" => nil
               })

      prompt = Prompts.get_prompt_with_versions!(prompt.id)
      assert prompt.versions == []
    end

    test "update_prompt_with_optional_version/2 updates prompt and creates new version" do
      prompt = prompt_fixture_with_version(%{template: "Original {{name}}", tags: ["old"]})

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt, %{
                 "name" => "Updated Prompt",
                 "tags" => "new, updated",
                 "template" => "Updated {{topic}}"
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Updated Prompt"
      assert prompt.tags == ["new", "updated"]
      assert Enum.map(prompt.versions, & &1.version) == [2, 1]
      assert hd(prompt.versions).template == "Updated {{topic}}"
      assert hd(prompt.versions).variables == ["topic"]
    end

    test "update_prompt_with_optional_version/2 does not create version when template is unchanged" do
      prompt = prompt_fixture_with_version(%{template: "Original {{name}}"})

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt, %{
                 "name" => "Renamed",
                 "template" => "Original {{name}}"
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Renamed"
      assert length(prompt.versions) == 1
      assert hd(prompt.versions).version == 1
    end

    test "update_prompt_with_optional_version/2 uses latest persisted version when versions are not preloaded" do
      prompt = prompt_fixture()
      {:ok, _v1} = Prompts.create_prompt_version(prompt, "Version 1 {{name}}")
      {:ok, _v2} = Prompts.create_prompt_version(prompt, "Version 2 {{topic}}")

      prompt_without_versions = Prompts.get_prompt!(prompt.id)

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt_without_versions, %{
                 "name" => "Renamed",
                 "template" => "Version 2 {{topic}}"
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Renamed"
      assert Enum.map(prompt.versions, & &1.version) == [2, 1]
      assert hd(prompt.versions).template == "Version 2 {{topic}}"
    end

    test "update_prompt_with_optional_version/2 uses highest version when preloaded versions are unordered" do
      prompt = prompt_fixture()
      {:ok, version1} = Prompts.create_prompt_version(prompt, "Version 1 {{name}}")
      {:ok, version2} = Prompts.create_prompt_version(prompt, "Version 2 {{topic}}")

      prompt_with_unordered_versions = %{
        prompt
        | versions: [version1, version2]
      }

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt_with_unordered_versions, %{
                 "name" => "Still Renamed",
                 "template" => "Version 2 {{topic}}"
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Still Renamed"
      assert Enum.map(prompt.versions, & &1.version) == [2, 1]
    end

    test "update_prompt_with_optional_version/2 creates first version when prompt has none" do
      prompt = prompt_fixture(%{name: "No Versions Yet"})

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt, %{
                 "name" => "Now Versioned",
                 "template" => "First template {{name}}"
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Now Versioned"
      assert Enum.map(prompt.versions, & &1.version) == [1]
      assert hd(prompt.versions).template == "First template {{name}}"
      assert hd(prompt.versions).variables == ["name"]
    end

    test "update_prompt_with_optional_version/2 treats nil template as blank" do
      prompt = prompt_fixture_with_version(%{template: "Original {{name}}"})

      assert {:ok, updated_prompt} =
               Prompts.update_prompt_with_optional_version(prompt, %{
                 "name" => "Renamed",
                 "template" => nil
               })

      prompt = Prompts.get_prompt_with_versions!(updated_prompt.id)
      assert prompt.name == "Renamed"
      assert Enum.map(prompt.versions, & &1.version) == [1]
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

    test "create_prompt_version/2 converts unique constraint violations into changeset errors" do
      prompt = prompt_fixture()
      repo = Aludel.Repo.get()

      assert {:ok, _version} =
               %PromptVersion{}
               |> PromptVersion.changeset(%{
                 prompt_id: prompt.id,
                 version: 1,
                 template: "Original {{name}}",
                 variables: ["name"]
               })
               |> repo.insert()

      assert {:error, changeset} =
               %PromptVersion{}
               |> PromptVersion.changeset(%{
                 prompt_id: prompt.id,
                 version: 1,
                 template: "Duplicate {{name}}",
                 variables: ["name"]
               })
               |> repo.insert()

      assert "has already been taken" in errors_on(changeset).prompt_id
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
      attrs = %{name: "Customer Support", type: :prompt}

      assert {:ok, project} = Projects.create_project(attrs)
      assert project.name == "Customer Support"
    end

    test "create_project/1 requires name" do
      assert {:error, changeset} = Projects.create_project(%{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "list_projects/0 returns all projects ordered by creation" do
      {:ok, p1} = Projects.create_project(%{name: "Project A", type: :prompt})
      {:ok, p2} = Projects.create_project(%{name: "Project B", type: :prompt})

      projects = Projects.list_projects()
      assert length(projects) == 2
      assert Enum.at(projects, 0).id == p1.id
      assert Enum.at(projects, 1).id == p2.id
    end

    test "get_project!/1 returns project with given id" do
      {:ok, project} = Projects.create_project(%{name: "Test Project", type: :prompt})
      assert Projects.get_project!(project.id).name == "Test Project"
    end

    test "update_project/2 updates project" do
      {:ok, project} = Projects.create_project(%{name: "Old Name", type: :prompt})
      assert {:ok, updated} = Projects.update_project(project, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "delete_project/1 deletes project" do
      {:ok, project} = Projects.create_project(%{name: "To Delete", type: :prompt})
      assert {:ok, _} = Projects.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(project.id) end
    end
  end

  describe "filtered prompt listing" do
    test "list_prompts/1 filters by project_id" do
      {:ok, project1} = Projects.create_project(%{name: "Project 1", type: :prompt})
      {:ok, project2} = Projects.create_project(%{name: "Project 2", type: :prompt})

      Prompts.create_prompt(%{name: "P1 Prompt", project_id: project1.id})
      Prompts.create_prompt(%{name: "P2 Prompt", project_id: project2.id})

      results = Prompts.list_prompts(%{project_id: project1.id})
      assert length(results) == 1
      assert hd(results).name == "P1 Prompt"
    end

    test "list_prompts/1 ignores blank project_id" do
      {:ok, project} = Projects.create_project(%{name: "Project", type: :prompt})

      Prompts.create_prompt(%{name: "Grouped Prompt", project_id: project.id})
      Prompts.create_prompt(%{name: "Ungrouped Prompt"})

      results = Prompts.list_prompts(%{project_id: ""})

      assert length(results) == 2
      assert Enum.any?(results, &(&1.name == "Grouped Prompt"))
      assert Enum.any?(results, &(&1.name == "Ungrouped Prompt"))
    end
  end
end
