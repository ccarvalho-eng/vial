defmodule Vial.Evals do
  @moduledoc """
  Context for managing evaluation suites, test cases, and runs.

  In embedded mode, all functions accept a repo as the first parameter.
  For standalone mode, you can pass Vial.Repo directly.
  """

  import Ecto.Query

  alias Vial.Evals.Suite
  alias Vial.Evals.SuiteRun
  alias Vial.Evals.TestCase
  alias Vial.LLM
  alias Vial.Prompts.PromptVersion
  alias Vial.Providers.Provider

  # Suite functions

  @doc """
  Lists all suites in the system.
  """
  @spec list_suites(module()) :: [Suite.t()]
  def list_suites(repo) do
    repo.all(Suite)
  end

  @doc """
  Lists all suites with their associated prompt preloaded.
  """
  @spec list_suites_with_prompt(module()) :: [Suite.t()]
  def list_suites_with_prompt(repo) do
    Suite
    |> preload(:prompt)
    |> repo.all()
  end

  @doc """
  Gets a suite by ID, raising if not found.
  """
  @spec get_suite!(module(), binary()) :: Suite.t()
  def get_suite!(repo, id) do
    repo.get!(Suite, id)
  end

  @doc """
  Gets a suite by ID with prompt preloaded, raising if not found.
  """
  @spec get_suite_with_prompt!(module(), binary()) :: Suite.t()
  def get_suite_with_prompt!(repo, id) do
    Suite
    |> repo.get!(id)
    |> repo.preload(:prompt)
  end

  @doc """
  Gets a suite with all test cases preloaded.
  """
  @spec get_suite_with_test_cases!(module(), binary()) :: Suite.t()
  def get_suite_with_test_cases!(repo, id) do
    Suite
    |> repo.get!(id)
    |> repo.preload(:test_cases)
  end

  @doc """
  Gets a suite with test cases and prompt preloaded.
  """
  @spec get_suite_with_test_cases_and_prompt!(module(), binary()) :: Suite.t()
  def get_suite_with_test_cases_and_prompt!(repo, id) do
    Suite
    |> repo.get!(id)
    |> repo.preload([:test_cases, :prompt])
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
  @spec create_suite(module(), map()) :: {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def create_suite(repo, attrs \\ %{}) do
    %Suite{}
    |> Suite.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing suite.
  """
  @spec update_suite(module(), Suite.t(), map()) ::
          {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def update_suite(repo, %Suite{} = suite, attrs) do
    suite
    |> Suite.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Deletes a suite.
  """
  @spec delete_suite(module(), Suite.t()) ::
          {:ok, Suite.t()} | {:error, Ecto.Changeset.t()}
  def delete_suite(repo, %Suite{} = suite) do
    repo.delete(suite)
  end

  # TestCase functions

  @doc """
  Lists all test cases in the system.
  """
  @spec list_test_cases(module()) :: [TestCase.t()]
  def list_test_cases(repo) do
    repo.all(TestCase)
  end

  @doc """
  Gets a test case by ID, raising if not found.
  """
  @spec get_test_case!(module(), binary()) :: TestCase.t()
  def get_test_case!(repo, id) do
    repo.get!(TestCase, id)
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
  @spec create_test_case(module(), map()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def create_test_case(repo, attrs \\ %{}) do
    %TestCase{}
    |> TestCase.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing test case.
  """
  @spec update_test_case(module(), TestCase.t(), map()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def update_test_case(repo, %TestCase{} = test_case, attrs) do
    test_case
    |> TestCase.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Deletes a test case.
  """
  @spec delete_test_case(module(), TestCase.t()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def delete_test_case(repo, %TestCase{} = test_case) do
    repo.delete(test_case)
  end

  # SuiteRun functions

  @doc """
  Lists all suite runs in the system.
  """
  @spec list_suite_runs(module()) :: [SuiteRun.t()]
  def list_suite_runs(repo) do
    repo.all(SuiteRun)
  end

  @doc """
  Gets suite runs for a specific suite.
  """
  def list_suite_runs_for_suite(repo, suite_id) do
    SuiteRun
    |> where([sr], sr.suite_id == ^suite_id)
    |> order_by([sr], desc: sr.inserted_at)
    |> repo.all()
  end

  @doc """
  Gets suite runs for a specific suite with prompt_version and provider
  preloaded.
  """
  def list_suite_runs_for_suite_with_associations(repo, suite_id) do
    SuiteRun
    |> where([sr], sr.suite_id == ^suite_id)
    |> order_by([sr], desc: sr.inserted_at)
    |> preload([:prompt_version, :provider])
    |> repo.all()
  end

  @doc """
  Calculates pass rates grouped by prompt.

  Returns a list of maps with prompt info and pass rate statistics.
  """
  @spec pass_rates_by_prompt(module()) :: [map()]
  def pass_rates_by_prompt(repo) do
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

    repo.all(query)
  end

  @doc """
  Gets a suite run by ID, raising if not found.
  """
  @spec get_suite_run!(module(), binary()) :: SuiteRun.t()
  def get_suite_run!(repo, id) do
    repo.get!(SuiteRun, id)
  end

  @doc """
  Creates a new suite run.
  """
  @spec create_suite_run(module(), map()) ::
          {:ok, SuiteRun.t()} | {:error, Ecto.Changeset.t()}
  def create_suite_run(repo, attrs \\ %{}) do
    %SuiteRun{}
    |> SuiteRun.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Deletes a suite run.
  """
  @spec delete_suite_run(module(), SuiteRun.t()) ::
          {:ok, SuiteRun.t()} | {:error, Ecto.Changeset.t()}
  def delete_suite_run(repo, %SuiteRun{} = suite_run) do
    repo.delete(suite_run)
  end

  @doc """
  Executes a test suite against a prompt version and provider.

  Runs all test cases for the suite, evaluating their assertions
  against the LLM output and creating a suite_run with results.

  ## Parameters
    - repo: The repo to use for database operations
    - suite: The test suite to execute
    - prompt_version: The prompt version to use
    - provider: The LLM provider to call

  ## Returns
    - `{:ok, suite_run}` with execution results
    - `{:error, reason}` if execution fails
  """
  @spec execute_suite(module(), Suite.t(), PromptVersion.t(), Provider.t()) ::
          {:ok, SuiteRun.t()} | {:error, term()}
  def execute_suite(repo, %Suite{} = suite, %PromptVersion{} = version, %Provider{} = provider) do
    suite = repo.preload(suite, :test_cases)

    {results, metrics} =
      Enum.map_reduce(
        suite.test_cases,
        %{total_cost: Decimal.new("0"), total_latency: 0, successful: 0},
        fn test_case, acc ->
          result = execute_test_case(test_case, version, provider)

          new_acc =
            case result do
              %{"cost_usd" => cost, "latency_ms" => latency}
              when not is_nil(cost) and not is_nil(latency) ->
                %{
                  total_cost: Decimal.add(acc.total_cost, Decimal.from_float(cost)),
                  total_latency: acc.total_latency + latency,
                  successful: acc.successful + 1
                }

              _ ->
                acc
            end

          {result, new_acc}
        end
      )

    passed = Enum.count(results, & &1["passed"])
    failed = Enum.count(results, &(!&1["passed"]))

    avg_cost_usd =
      if metrics.successful > 0 do
        Decimal.div(metrics.total_cost, metrics.successful)
      else
        nil
      end

    avg_latency_ms =
      if metrics.successful > 0 do
        round(metrics.total_latency / metrics.successful)
      else
        nil
      end

    create_suite_run(repo, %{
      suite_id: suite.id,
      prompt_version_id: version.id,
      provider_id: provider.id,
      results: results,
      passed: passed,
      failed: failed,
      avg_cost_usd: avg_cost_usd,
      avg_latency_ms: avg_latency_ms
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
          "output" => result.output,
          "cost_usd" => result.cost_usd,
          "latency_ms" => result.latency_ms
        }

      {:error, _reason} ->
        %{
          "test_case_id" => test_case.id,
          "passed" => false,
          "output" => nil,
          "cost_usd" => nil,
          "latency_ms" => nil
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
