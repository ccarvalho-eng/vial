defmodule Vial.Evals do
  @moduledoc """
  Context for managing evaluation suites, test cases, and runs.
  """

  import Ecto.Query

  alias Vial.Repo
  alias Vial.Evals.Suite
  alias Vial.Evals.TestCase
  alias Vial.Evals.SuiteRun
  alias Vial.Prompts.PromptVersion
  alias Vial.Providers.Provider
  alias Vial.LLM

  # Suite functions

  @doc """
  Lists all suites in the system.
  """
  @spec list_suites() :: [Suite.t()]
  def list_suites do
    Repo.all(Suite)
  end

  @doc """
  Gets a suite by ID, raising if not found.
  """
  @spec get_suite!(binary()) :: Suite.t()
  def get_suite!(id) do
    Repo.get!(Suite, id)
  end

  @doc """
  Gets a suite with all test cases preloaded.
  """
  @spec get_suite_with_test_cases!(binary()) :: Suite.t()
  def get_suite_with_test_cases!(id) do
    Suite
    |> Repo.get!(id)
    |> Repo.preload(:test_cases)
  end

  @doc """
  Returns a changeset for tracking suite changes.
  """
  @spec change_suite(Suite.t(), map()) :: Ecto.Changeset.t()
  def change_suite(%Suite{} = suite, attrs \\ %{}) do
    Suite.changeset(suite, attrs)
  end

  @doc """
  Creates a new suite.
  """
  @spec create_suite(map()) :: {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def create_suite(attrs \\ %{}) do
    %Suite{}
    |> Suite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing suite.
  """
  @spec update_suite(Suite.t(), map()) ::
          {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def update_suite(%Suite{} = suite, attrs) do
    suite
    |> Suite.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a suite.
  """
  @spec delete_suite(Suite.t()) ::
          {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def delete_suite(%Suite{} = suite) do
    Repo.delete(suite)
  end

  # TestCase functions

  @doc """
  Lists all test cases in the system.
  """
  @spec list_test_cases() :: [TestCase.t()]
  def list_test_cases do
    Repo.all(TestCase)
  end

  @doc """
  Gets a test case by ID, raising if not found.
  """
  @spec get_test_case!(binary()) :: TestCase.t()
  def get_test_case!(id) do
    Repo.get!(TestCase, id)
  end

  @doc """
  Returns a changeset for tracking test case changes.
  """
  @spec change_test_case(TestCase.t(), map()) :: Ecto.Changeset.t()
  def change_test_case(%TestCase{} = test_case, attrs \\ %{}) do
    TestCase.changeset(test_case, attrs)
  end

  @doc """
  Creates a new test case.
  """
  @spec create_test_case(map()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def create_test_case(attrs \\ %{}) do
    %TestCase{}
    |> TestCase.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing test case.
  """
  @spec update_test_case(TestCase.t(), map()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def update_test_case(%TestCase{} = test_case, attrs) do
    test_case
    |> TestCase.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a test case.
  """
  @spec delete_test_case(TestCase.t()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def delete_test_case(%TestCase{} = test_case) do
    Repo.delete(test_case)
  end

  # SuiteRun functions

  @doc """
  Lists all suite runs in the system.
  """
  @spec list_suite_runs() :: [SuiteRun.t()]
  def list_suite_runs do
    Repo.all(SuiteRun)
  end

  @doc """
  Gets suite runs for a specific suite.
  """
  def list_suite_runs_for_suite(suite_id) do
    SuiteRun
    |> where([sr], sr.suite_id == ^suite_id)
    |> order_by([sr], desc: sr.inserted_at)
    |> Repo.all()
  end

  @doc """
  Calculates pass rates grouped by prompt.

  Returns a list of maps with prompt info and pass rate statistics.
  """
  @spec pass_rates_by_prompt() :: [map()]
  def pass_rates_by_prompt do
    query =
      from sr in SuiteRun,
        join: pv in assoc(sr, :prompt_version),
        join: p in assoc(pv, :prompt),
        group_by: [p.id, p.name],
        select: %{
          prompt_id: p.id,
          prompt_name: p.name,
          total_passed: sum(sr.passed),
          total_failed: sum(sr.failed)
        }

    Repo.all(query)
  end

  @doc """
  Gets a suite run by ID, raising if not found.
  """
  @spec get_suite_run!(binary()) :: SuiteRun.t()
  def get_suite_run!(id) do
    Repo.get!(SuiteRun, id)
  end

  @doc """
  Creates a new suite run.
  """
  @spec create_suite_run(map()) ::
          {:ok, SuiteRun.t()} | {:error, Ecto.Changeset.t()}
  def create_suite_run(attrs \\ %{}) do
    %SuiteRun{}
    |> SuiteRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a suite run.
  """
  @spec delete_suite_run(SuiteRun.t()) ::
          {:ok, SuiteRun.t()} | {:error, Ecto.Changeset.t()}
  def delete_suite_run(%SuiteRun{} = suite_run) do
    Repo.delete(suite_run)
  end

  @doc """
  Executes a test suite against a prompt version and provider.

  Runs all test cases for the suite, evaluating their assertions
  against the LLM output and creating a suite_run with results.

  ## Parameters
    - suite: The test suite to execute
    - prompt_version: The prompt version to use
    - provider: The LLM provider to call

  ## Returns
    - `{:ok, suite_run}` with execution results
    - `{:error, reason}` if execution fails
  """
  @spec execute_suite(Suite.t(), PromptVersion.t(), Provider.t()) ::
          {:ok, SuiteRun.t()} | {:error, term()}
  def execute_suite(%Suite{} = suite, %PromptVersion{} = version, %Provider{} = provider) do
    suite = Repo.preload(suite, :test_cases)

    results =
      Enum.map(suite.test_cases, fn test_case ->
        execute_test_case(test_case, version, provider)
      end)

    passed = Enum.count(results, & &1["passed"])
    failed = Enum.count(results, &(!&1["passed"]))

    create_suite_run(%{
      suite_id: suite.id,
      prompt_version_id: version.id,
      provider_id: provider.id,
      results: results,
      passed: passed,
      failed: failed
    })
  end

  defp execute_test_case(test_case, version, provider) do
    rendered_prompt = render_template(version.template, test_case.variable_values)

    case LLM.call(provider, rendered_prompt) do
      {:ok, result} ->
        passed = evaluate_assertions(result.output, test_case.assertions)

        %{
          "test_case_id" => test_case.id,
          "passed" => passed,
          "output" => result.output
        }

      {:error, _reason} ->
        %{
          "test_case_id" => test_case.id,
          "passed" => false,
          "output" => nil
        }
    end
  end

  defp render_template(template, variables) do
    Enum.reduce(variables, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end

  defp evaluate_assertions(output, assertions) do
    Enum.all?(assertions, fn assertion ->
      evaluate_assertion(output, assertion)
    end)
  end

  defp evaluate_assertion(output, %{"type" => "contains", "value" => value}) do
    String.contains?(output, value)
  end

  defp evaluate_assertion(output, %{"type" => "not_contains", "value" => value}) do
    !String.contains?(output, value)
  end

  defp evaluate_assertion(output, %{"type" => "regex", "value" => pattern}) do
    Regex.match?(~r/#{pattern}/, output)
  end

  defp evaluate_assertion(output, %{"type" => "exact_match", "value" => value}) do
    output == value
  end
end
