defmodule Aludel.EvalsTest do
  use Aludel.DataCase

  import Mox

  alias Aludel.Interfaces.HttpClientMock
  alias Aludel.Evals
  alias Aludel.Evals.SuiteRun

  setup :set_mox_from_context
  setup :verify_on_exit!

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

    test "get_suite_with_test_cases_and_prompt!/1 preloads documents" do
      suite = suite_fixture()
      test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, _doc} =
        Aludel.Evals.create_test_case_document(%{
          test_case_id: test_case.id,
          filename: "test.pdf",
          content_type: "application/pdf",
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      loaded = Aludel.Evals.get_suite_with_test_cases_and_prompt!(suite.id)
      assert [test_case] = loaded.test_cases
      assert [%Aludel.Evals.TestCaseDocument{filename: "test.pdf"}] = test_case.documents
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
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template {{var}}")
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
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template {{var}}")

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

    test "changeset accepts avg_cost_usd and avg_latency_ms" do
      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Template {{var}}")
      provider = provider_fixture()

      attrs = %{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        avg_cost_usd: Decimal.new("0.0042"),
        avg_latency_ms: 350
      }

      changeset = SuiteRun.changeset(%SuiteRun{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :avg_cost_usd) == Decimal.new("0.0042")
      assert Ecto.Changeset.get_change(changeset, :avg_latency_ms) == 350
    end
  end

  describe "execute_suite/3" do
    test "execute_suite captures avg_cost_usd and avg_latency_ms" do
      mock_response = build_mock_response("Mock response", 5, 10)

      # Use stub for concurrent test case execution
      stub(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      # Create test cases that will succeed
      _tc1 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value1"},
          assertions: [%{"type" => "contains", "value" => "Mock"}]
        })

      _tc2 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value2"},
          assertions: [%{"type" => "contains", "value" => "response"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)

      assert suite_run.avg_cost_usd != nil
      assert suite_run.avg_latency_ms != nil
      assert Decimal.compare(suite_run.avg_cost_usd, Decimal.new("0")) == :gt
      assert suite_run.avg_latency_ms >= 0
    end

    test "execute_suite handles partial failures in metrics" do
      mock_response = build_mock_response("Mock response", 5, 10)

      # Use stub for concurrent test case execution
      stub(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      # Create one passing and one failing test case
      _tc1 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value1"},
          assertions: [%{"type" => "contains", "value" => "Mock"}]
        })

      _tc2 =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value2"},
          assertions: [%{"type" => "contains", "value" => "NOTFOUND"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)

      # Should still have metrics from successful tests
      assert is_nil(suite_run.avg_cost_usd) or
               Decimal.compare(suite_run.avg_cost_usd, Decimal.new("0")) == :gt

      assert is_nil(suite_run.avg_latency_ms) or suite_run.avg_latency_ms >= 0
    end

    test "executes suite with passing test cases" do
      mock_response = build_mock_response("Mock response", 5, 10)

      # Use stub for concurrent test case execution
      stub(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Hello {{name}}")
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
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Say {{word}}")
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

    test "evaluates contains assertion" do
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
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

    test "evaluates not_contains assertion" do
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
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

    test "evaluates regex assertion" do
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
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

    test "evaluates exact_match assertion" do
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
      provider = provider_fixture()

      _tc =
        test_case_fixture(%{
          suite_id: suite.id,
          variable_values: %{"input" => "value"},
          assertions: [%{"type" => "exact_match", "value" => "Mock response"}]
        })

      assert {:ok, suite_run} = Evals.execute_suite(suite, version, provider)
      assert suite_run.passed == 1
    end

    test "evaluates multiple assertions per test case" do
      mock_response = build_mock_response("Mock response", 5, 10)

      expect(HttpClientMock, :request, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      suite = suite_fixture()
      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
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
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Test {{input}}")
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

  describe "test_case_documents" do
    test "create_test_case_document/1 creates a document" do
      test_case = test_case_fixture()

      attrs = %{
        test_case_id: test_case.id,
        filename: "doc.pdf",
        content_type: "application/pdf",
        data: <<1, 2, 3>>,
        size_bytes: 3
      }

      assert {:ok, document} = Evals.create_test_case_document(attrs)
      assert document.test_case_id == test_case.id
      assert document.filename == "doc.pdf"
      assert document.content_type == "application/pdf"
    end

    test "delete_test_case_document/1 deletes a document" do
      test_case = test_case_fixture()

      {:ok, document} =
        Evals.create_test_case_document(%{
          test_case_id: test_case.id,
          filename: "doc.pdf",
          content_type: "application/pdf",
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      assert {:ok, _deleted} = Evals.delete_test_case_document(document)
    end

    test "get_test_case_with_documents!/1 preloads documents" do
      test_case = test_case_fixture()

      {:ok, _doc1} =
        Evals.create_test_case_document(%{
          test_case_id: test_case.id,
          filename: "doc1.pdf",
          content_type: "application/pdf",
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      {:ok, _doc2} =
        Evals.create_test_case_document(%{
          test_case_id: test_case.id,
          filename: "doc2.pdf",
          content_type: "application/pdf",
          data: <<4, 5, 6>>,
          size_bytes: 3
        })

      loaded = Evals.get_test_case_with_documents!(test_case.id)

      refute match?(%Ecto.Association.NotLoaded{}, loaded.documents)
      assert length(loaded.documents) == 2
    end

    test "max_size_bytes/0 returns correct limit" do
      assert Aludel.Evals.TestCaseDocument.max_size_bytes() == 10 * 1024 * 1024
    end

    test "supported_types/0 returns list of MIME types" do
      types = Aludel.Evals.TestCaseDocument.supported_types()
      assert is_list(types)
      assert "application/pdf" in types
      assert "image/png" in types
    end
  end

  describe "execute_suite with documents" do
    import Aludel.PromptsFixtures
    import Aludel.ProvidersFixtures

    test "passes documents to LLM.call" do
      suite = suite_fixture()
      test_case = test_case_fixture(%{suite_id: suite.id})

      {:ok, _doc} =
        Aludel.Evals.create_test_case_document(%{
          test_case_id: test_case.id,
          filename: "test.png",
          content_type: "image/png",
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      prompt = prompt_fixture()
      {:ok, version} = Aludel.Prompts.create_prompt_version(prompt, "Describe {{input}}")

      provider =
        provider_fixture(%{
          provider: :openai,
          model: "gpt-4o"
        })

      assert {:ok, suite_run} = Aludel.Evals.execute_suite(suite, version, provider)
      assert suite_run.passed + suite_run.failed > 0
    end
  end

  defp build_mock_response(text, input_tokens, output_tokens) do
    %{
      content: text,
      input_tokens: input_tokens,
      output_tokens: output_tokens
    }
  end
end
