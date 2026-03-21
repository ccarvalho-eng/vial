defmodule Vial.EvalsTest do
  use Vial.DataCase, async: true

  alias Vial.Evals

  describe "suites" do
    test "create_suite/1 creates a suite with valid attributes" do
      prompt = prompt_fixture()

      attrs = %{
        name: "Test Suite",
        prompt_id: prompt.id
      }

      assert {:ok, suite} = Evals.create_suite(attrs)
      assert suite.name == "Test Suite"
      assert suite.prompt_id == prompt.id
    end

    test "create_suite/1 requires name" do
      prompt = prompt_fixture()

      attrs = %{prompt_id: prompt.id}

      assert {:error, changeset} = Evals.create_suite(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "create_suite/1 requires prompt_id" do
      attrs = %{name: "Test Suite"}

      assert {:error, changeset} = Evals.create_suite(attrs)
      assert "can't be blank" in errors_on(changeset).prompt_id
    end

    test "list_suites/0 returns all suites" do
      suite = suite_fixture()
      suites = Evals.list_suites()

      assert length(suites) == 1
      assert hd(suites).id == suite.id
    end

    test "get_suite!/1 returns the suite with given id" do
      suite = suite_fixture()
      fetched_suite = Evals.get_suite!(suite.id)

      assert fetched_suite.id == suite.id
      assert fetched_suite.name == suite.name
    end

    test "get_suite_with_test_cases!/1 preloads test cases" do
      suite = suite_fixture()
      _test_case = test_case_fixture(%{suite_id: suite.id})

      fetched_suite = Evals.get_suite_with_test_cases!(suite.id)

      assert fetched_suite.id == suite.id
      refute match?(%Ecto.Association.NotLoaded{}, fetched_suite.test_cases)
      assert length(fetched_suite.test_cases) == 1
    end

    test "update_suite/2 updates the suite" do
      suite = suite_fixture()

      assert {:ok, updated_suite} = Evals.update_suite(suite, %{name: "Updated"})
      assert updated_suite.name == "Updated"
    end

    test "delete_suite/1 deletes the suite" do
      suite = suite_fixture()

      assert {:ok, _suite} = Evals.delete_suite(suite)
      assert_raise Ecto.NoResultsError, fn -> Evals.get_suite!(suite.id) end
    end

    test "change_suite/1 returns a suite changeset" do
      suite = suite_fixture()
      changeset = Evals.change_suite(suite)

      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "test_cases" do
    test "create_test_case/1 creates a test case with valid attributes" do
      suite = suite_fixture()

      attrs = %{
        suite_id: suite.id,
        variable_values: %{"name" => "John"},
        assertions: [%{"type" => "contains", "value" => "Hello"}]
      }

      assert {:ok, test_case} = Evals.create_test_case(attrs)
      assert test_case.suite_id == suite.id
      assert test_case.variable_values == %{"name" => "John"}
      assert test_case.assertions == [%{"type" => "contains", "value" => "Hello"}]
    end

    test "create_test_case/1 requires suite_id" do
      attrs = %{
        variable_values: %{},
        assertions: []
      }

      assert {:error, changeset} = Evals.create_test_case(attrs)
      assert "can't be blank" in errors_on(changeset).suite_id
    end

    test "create_test_case/1 requires variable_values" do
      suite = suite_fixture()

      attrs = %{
        suite_id: suite.id,
        assertions: []
      }

      assert {:error, changeset} = Evals.create_test_case(attrs)
      assert "can't be blank" in errors_on(changeset).variable_values
    end

    test "create_test_case/1 requires assertions" do
      suite = suite_fixture()

      attrs = %{
        suite_id: suite.id,
        variable_values: %{}
      }

      assert {:error, changeset} = Evals.create_test_case(attrs)
      assert "can't be blank" in errors_on(changeset).assertions
    end

    test "list_test_cases/0 returns all test cases" do
      test_case = test_case_fixture()
      test_cases = Evals.list_test_cases()

      assert length(test_cases) == 1
      assert hd(test_cases).id == test_case.id
    end

    test "get_test_case!/1 returns the test case with given id" do
      test_case = test_case_fixture()
      fetched = Evals.get_test_case!(test_case.id)

      assert fetched.id == test_case.id
    end

    test "update_test_case/2 updates the test case" do
      test_case = test_case_fixture()

      assert {:ok, updated} =
               Evals.update_test_case(test_case, %{variable_values: %{"new" => "value"}})

      assert updated.variable_values == %{"new" => "value"}
    end

    test "delete_test_case/1 deletes the test case" do
      test_case = test_case_fixture()

      assert {:ok, _test_case} = Evals.delete_test_case(test_case)
      assert_raise Ecto.NoResultsError, fn -> Evals.get_test_case!(test_case.id) end
    end

    test "change_test_case/1 returns a test case changeset" do
      test_case = test_case_fixture()
      changeset = Evals.change_test_case(test_case)

      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "suite_runs" do
    test "create_suite_run/1 creates a suite run with valid attributes" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      attrs = %{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        results: [%{"test_case_id" => "123", "passed" => true}],
        passed: 1,
        failed: 0
      }

      assert {:ok, suite_run} = Evals.create_suite_run(attrs)
      assert suite_run.suite_id == suite.id
      assert suite_run.prompt_version_id == version.id
      assert suite_run.provider_id == provider.id
      assert suite_run.results == [%{"test_case_id" => "123", "passed" => true}]
      assert suite_run.passed == 1
      assert suite_run.failed == 0
    end

    test "create_suite_run/1 requires suite_id" do
      attrs = %{results: [], passed: 0, failed: 0}

      assert {:error, changeset} = Evals.create_suite_run(attrs)
      assert "can't be blank" in errors_on(changeset).suite_id
    end

    test "create_suite_run/1 requires prompt_version_id" do
      suite = suite_fixture()

      attrs = %{suite_id: suite.id, results: [], passed: 0, failed: 0}

      assert {:error, changeset} = Evals.create_suite_run(attrs)
      assert "can't be blank" in errors_on(changeset).prompt_version_id
    end

    test "create_suite_run/1 requires provider_id" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")

      attrs = %{
        suite_id: suite.id,
        prompt_version_id: version.id,
        results: [],
        passed: 0,
        failed: 0
      }

      assert {:error, changeset} = Evals.create_suite_run(attrs)
      assert "can't be blank" in errors_on(changeset).provider_id
    end

    test "list_suite_runs/0 returns all suite runs" do
      suite_run = suite_run_fixture()
      suite_runs = Evals.list_suite_runs()

      assert length(suite_runs) == 1
      assert hd(suite_runs).id == suite_run.id
    end

    test "get_suite_run!/1 returns the suite run with given id" do
      suite_run = suite_run_fixture()
      fetched = Evals.get_suite_run!(suite_run.id)

      assert fetched.id == suite_run.id
    end

    test "delete_suite_run/1 deletes the suite run" do
      suite_run = suite_run_fixture()

      assert {:ok, _suite_run} = Evals.delete_suite_run(suite_run)
      assert_raise Ecto.NoResultsError, fn -> Evals.get_suite_run!(suite_run.id) end
    end
  end

  describe "execute_suite/3" do
    @tag :openai_integration
    test "executes suite with passing test cases" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Hello {{name}}")
      provider = provider_fixture()

      _tc1 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"name" => "Alice"},
          assertions: [%{"type" => "contains", "value" => "Mock"}]
        })

      _tc2 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"name" => "Bob"},
          assertions: [%{"type" => "contains", "value" => "Mock"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.suite_id == suite.id
      assert suite_run.prompt_version_id == version.id
      assert suite_run.provider_id == provider.id
      assert suite_run.passed == 2
      assert suite_run.failed == 0
      assert length(suite_run.results) == 2

      assert Enum.all?(suite_run.results, &(&1["passed"] == true))
    end

    test "executes suite with failing test cases" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Say {{word}}")
      provider = provider_fixture()

      _tc1 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"word" => "hello"},
          assertions: [%{"type" => "contains", "value" => "NOTFOUND"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 0
      assert suite_run.failed == 1
    end

    @tag :openai_integration
    test "evaluates contains assertion" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [%{"type" => "contains", "value" => "Mock"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
      assert suite_run.failed == 0
    end

    @tag :openai_integration
    test "evaluates not_contains assertion" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [%{"type" => "not_contains", "value" => "NOTFOUND"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
    end

    @tag :openai_integration
    test "evaluates regex assertion" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [%{"type" => "regex", "value" => "Mock.*response"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
    end

    @tag :openai_integration
    test "evaluates exact_match assertion" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [
            %{"type" => "exact_match", "value" => "Mock OpenAI response for: Test value"}
          ]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
    end

    @tag :openai_integration
    test "evaluates multiple assertions per test case" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [
            %{"type" => "contains", "value" => "Mock"},
            %{"type" => "not_contains", "value" => "NOTFOUND"},
            %{"type" => "regex", "value" => "response"}
          ]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
    end

    test "fails if any assertion fails" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [
            %{"type" => "contains", "value" => "Mock"},
            %{"type" => "contains", "value" => "NOTFOUND"}
          ]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.failed == 1
    end
  end
end
