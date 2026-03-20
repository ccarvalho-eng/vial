defmodule Vial.Evals.SuiteRunTest do
  use Vial.DataCase, async: true

  alias Vial.Evals.SuiteRun

  describe "changeset/2" do
    test "valid changeset with all fields" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          results: [%{"test_case_id" => "123", "passed" => true}],
          passed: 5,
          failed: 2
        })

      assert changeset.valid?
    end

    test "requires suite_id" do
      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          results: [],
          passed: 0,
          failed: 0
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).suite_id
    end

    test "requires prompt_version_id" do
      suite = suite_fixture()

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          results: [],
          passed: 0,
          failed: 0
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).prompt_version_id
    end

    test "requires provider_id" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          results: [],
          passed: 0,
          failed: 0
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).provider_id
    end

    test "defaults results to empty list" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 0,
          failed: 0
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :results) == []
    end

    test "defaults passed to 0" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          results: [],
          failed: 0
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :passed) == 0
    end

    test "defaults failed to 0" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      changeset =
        SuiteRun.changeset(%SuiteRun{}, %{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          results: [],
          passed: 0
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :failed) == 0
    end
  end
end
