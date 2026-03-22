defmodule Vial.PromptsTest do
  use Vial.DataCase, async: true

  alias Vial.Prompts

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
end
