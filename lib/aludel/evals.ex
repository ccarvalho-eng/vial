defmodule Aludel.Evals do
  @moduledoc """
  Context for managing evaluation suites, test cases, and runs.
  """

  import Ecto.Query

  alias Aludel.Evals.{Suite, SuiteRun, SuiteRunner, TestCase, TestCaseDocument}
  alias Aludel.LLM
  alias Aludel.Prompts.PromptVersion
  alias Aludel.Providers.Provider
  alias Aludel.Storage
  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset

  # Suite functions

  @doc """
  Lists all suites in the system.
  """
  @spec list_suites() :: [Suite.t()]
  def list_suites do
    repo().all(Suite)
  end

  @doc """
  Lists all suites with their associated prompt preloaded.
  """
  @spec list_suites_with_prompt() :: [Suite.t()]
  def list_suites_with_prompt do
    Suite
    |> preload(:prompt)
    |> repo().all()
  end

  @doc """
  Gets a suite by ID, raising if not found.
  """
  @spec get_suite!(binary()) :: Suite.t()
  def get_suite!(id) do
    repo().get!(Suite, id)
  end

  @doc """
  Gets a suite by ID with prompt preloaded, raising if not found.
  """
  @spec get_suite_with_prompt!(binary()) :: Suite.t()
  def get_suite_with_prompt!(id) do
    Suite
    |> repo().get!(id)
    |> repo().preload(:prompt)
  end

  @doc """
  Gets a suite with all test cases preloaded.
  """
  @spec get_suite_with_test_cases!(binary()) :: Suite.t()
  def get_suite_with_test_cases!(id) do
    Suite
    |> repo().get!(id)
    |> repo().preload(:test_cases)
  end

  @doc """
  Gets a suite with test cases and prompt preloaded.
  """
  @spec get_suite_with_test_cases_and_prompt!(binary()) :: Suite.t()
  def get_suite_with_test_cases_and_prompt!(id) do
    test_cases_query = from tc in TestCase, order_by: [desc: tc.inserted_at]

    Suite
    |> repo().get!(id)
    |> repo().preload(test_cases: {test_cases_query, :documents}, prompt: [])
  end

  @doc """
  Returns a changeset for tracking suite changes.
  """
  @spec change_suite(Suite.t(), map()) :: Changeset.t()
  def change_suite(%Suite{} = suite, attrs \\ %{}) do
    Suite.changeset(suite, attrs)
  end

  @doc """
  Creates a new suite.
  """
  @spec create_suite(map()) :: {:ok, Suite.t()} | {:error, Changeset.t()}
  def create_suite(attrs \\ %{}) do
    %Suite{}
    |> Suite.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing suite.
  """
  @spec update_suite(Suite.t(), map()) ::
          {:ok, Suite.t()} | {:error, Changeset.t()}
  def update_suite(%Suite{} = suite, attrs) do
    suite
    |> Suite.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a suite.
  """
  @spec delete_suite(Suite.t()) ::
          {:ok, Suite.t()} | {:error, Changeset.t()}
  def delete_suite(%Suite{} = suite) do
    repo().delete(suite)
  end

  # TestCase functions

  @doc """
  Lists all test cases in the system.
  """
  @spec list_test_cases() :: [TestCase.t()]
  def list_test_cases do
    repo().all(TestCase)
  end

  @doc """
  Gets a test case by ID, raising if not found.
  """
  @spec get_test_case!(binary()) :: TestCase.t()
  def get_test_case!(id) do
    repo().get!(TestCase, id)
  end

  @doc """
  Gets a single test case document.

  Raises `Ecto.NoResultsError` if the document does not exist.
  """
  @spec get_test_case_document!(binary()) :: TestCaseDocument.t()
  def get_test_case_document!(id) do
    repo().get!(TestCaseDocument, id)
  end

  @doc """
  Returns a changeset for tracking test case changes.
  """
  @spec change_test_case(TestCase.t(), map()) :: Changeset.t()
  def change_test_case(%TestCase{} = test_case, attrs \\ %{}) do
    TestCase.changeset(test_case, attrs)
  end

  @doc """
  Creates a new test case.
  """
  @spec create_test_case(map()) ::
          {:ok, TestCase.t()} | {:error, Changeset.t()}
  def create_test_case(attrs \\ %{}) do
    %TestCase{}
    |> TestCase.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing test case.
  """
  @spec update_test_case(TestCase.t(), map()) ::
          {:ok, TestCase.t()} | {:error, Changeset.t()}
  def update_test_case(%TestCase{} = test_case, attrs) do
    test_case
    |> TestCase.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a test case.
  """
  @spec delete_test_case(TestCase.t()) ::
          {:ok, TestCase.t()} | {:error, Changeset.t()}
  def delete_test_case(%TestCase{} = test_case) do
    repo().delete(test_case)
  end

  # SuiteRun functions

  @doc """
  Lists all suite runs in the system.
  """
  @spec list_suite_runs() :: [SuiteRun.t()]
  def list_suite_runs do
    repo().all(SuiteRun)
  end

  @doc """
  Gets suite runs for a specific suite.
  """
  def list_suite_runs_for_suite(suite_id) do
    SuiteRun
    |> where([sr], sr.suite_id == ^suite_id)
    |> order_by([sr], desc: sr.inserted_at)
    |> repo().all()
  end

  @doc """
  Gets suite runs for a specific suite with prompt_version and provider
  preloaded.
  """
  def list_suite_runs_for_suite_with_associations(suite_id) do
    SuiteRun
    |> where([sr], sr.suite_id == ^suite_id)
    |> order_by([sr], desc: sr.inserted_at)
    |> preload([:prompt_version, :provider])
    |> repo().all()
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

    repo().all(query)
  end

  @doc """
  Gets a suite run by ID, raising if not found.
  """
  @spec get_suite_run!(binary()) :: SuiteRun.t()
  def get_suite_run!(id) do
    repo().get!(SuiteRun, id)
  end

  @doc """
  Reloads a suite run with associations preloaded.
  """
  @spec reload_suite_run_with_associations(SuiteRun.t()) :: SuiteRun.t()
  def reload_suite_run_with_associations(%SuiteRun{} = suite_run) do
    repo().preload(suite_run, [:prompt_version, :provider], force: true)
  end

  @doc """
  Creates a new suite run.
  """
  @spec create_suite_run(map()) ::
          {:ok, SuiteRun.t()} | {:error, Changeset.t()}
  def create_suite_run(attrs \\ %{}) do
    %SuiteRun{}
    |> SuiteRun.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Deletes a suite run.
  """
  @spec delete_suite_run(SuiteRun.t()) ::
          {:ok, SuiteRun.t()} | {:error, Changeset.t()}
  def delete_suite_run(%SuiteRun{} = suite_run) do
    repo().delete(suite_run)
  end

  @doc """
  Retries a single test case result within an existing suite run.

  The existing embedded result is replaced in-place and the suite run
  aggregates are recalculated from the updated result set.
  """
  @spec retry_suite_run_test_case(SuiteRun.t(), binary()) ::
          {:ok, SuiteRun.t()} | {:error, term()}
  def retry_suite_run_test_case(%SuiteRun{} = suite_run, test_case_id)
      when is_binary(test_case_id) do
    with {:ok, existing_result} <- fetch_suite_run_result(suite_run, test_case_id),
         {:ok, test_case} <- fetch_suite_test_case(suite_run.suite_id, test_case_id),
         {:ok, version} <- fetch_prompt_version(suite_run.prompt_version_id),
         {:ok, provider} <- fetch_provider(suite_run.provider_id) do
      retried_result =
        test_case
        |> execute_test_case(version, provider)
        |> merge_retry_metadata(existing_result)

      updated_results = replace_suite_run_result(suite_run.results, test_case_id, retried_result)

      suite_run
      |> SuiteRun.changeset(
        Map.put(summarize_suite_results(updated_results), :results, updated_results)
      )
      |> repo().update()
    end
  rescue
    error ->
      {:error, {:retry_failed, Exception.message(error)}}
  catch
    kind, reason ->
      {:error, {:retry_failed, {kind, reason}}}
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
    suite = repo().preload(suite, test_cases: :documents)

    results = Enum.map(suite.test_cases, &execute_test_case(&1, version, provider))
    summary = summarize_suite_results(results)

    create_suite_run(
      Map.merge(summary, %{
        suite_id: suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        results: results
      })
    )
  end

  @doc """
  Launches suite execution in a supervised task and reports completion
  back to the given recipient process.
  """
  @spec launch_suite_execution(pid(), binary(), binary(), binary()) ::
          {:ok, reference()} | {:error, term()}
  def launch_suite_execution(recipient, suite_id, version_id, provider_id) do
    case SuiteRunner.launch(recipient, suite_id, version_id, provider_id) do
      {:ok, task_pid} -> {:ok, Process.monitor(task_pid)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Test Case Document functions

  @doc """
  Creates a test case document.
  """
  @spec create_test_case_document(map()) ::
          {:ok, TestCaseDocument.t()} | {:error, Changeset.t()}
  def create_test_case_document(attrs \\ %{}) do
    document = %TestCaseDocument{id: Ecto.UUID.generate()}
    changeset = TestCaseDocument.create_changeset(document, attrs)

    if changeset.valid? do
      persist_document_externally(changeset)
    else
      {:error, changeset}
    end
  end

  @doc """
  Deletes a test case document.
  """
  @spec delete_test_case_document(TestCaseDocument.t()) ::
          {:ok, TestCaseDocument.t()} | {:error, Changeset.t()}
  def delete_test_case_document(%TestCaseDocument{} = document) do
    repo().transaction(fn ->
      with {:ok, deleted_document} <- repo().delete(document),
           :ok <- Storage.delete(document.storage_key, storage_backend: document.storage_backend) do
        deleted_document
      else
        {:error, %Changeset{} = changeset} ->
          repo().rollback({:document, changeset})

        {:error, reason} ->
          changeset = add_storage_error(Changeset.change(document), reason)
          repo().rollback({:storage, changeset})
      end
    end)
    |> case do
      {:ok, deleted_document} ->
        {:ok, deleted_document}

      {:error, {:document, changeset}} ->
        {:error, changeset}

      {:error, {:storage, changeset}} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a test case with documents preloaded.
  """
  @spec get_test_case_with_documents!(binary()) :: TestCase.t()
  def get_test_case_with_documents!(id) do
    TestCase
    |> repo().get!(id)
    |> repo().preload(:documents)
  end

  # Private functions

  defp execute_test_case(test_case, version, provider) do
    test_case = ensure_documents_loaded(test_case)
    rendered_prompt = render_template(version.template, test_case.variable_values)

    case load_document_inputs(test_case.documents) do
      {:ok, documents} ->
        case LLM.call(provider, rendered_prompt, llm_call_opts(documents)) do
          {:ok, result} ->
            assertion_results = build_assertion_results(test_case.assertions, result.output)
            passed = Enum.all?(assertion_results, & &1["passed"])
            successful_test_case_result(test_case.id, result, passed, assertion_results)

          {:error, reason} ->
            failed_test_case_result(test_case.id, reason)
        end

      {:error, reason} ->
        failed_test_case_result(test_case.id, reason)
    end
  end

  defp llm_call_opts(documents) do
    if documents != [], do: [documents: documents], else: []
  end

  defp load_document_inputs(documents) do
    documents
    |> Task.async_stream(&load_document_input/1, timeout: :infinity)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, input}}, {:ok, loaded_documents} ->
        {:cont, {:ok, [input | loaded_documents]}}

      {:ok, {:error, reason}}, _acc ->
        {:halt, {:error, reason}}

      {:exit, reason}, _acc ->
        {:halt, {:error, {:document_storage_error, :unknown_document, reason}}}
    end)
    |> case do
      {:ok, loaded_documents} -> {:ok, Enum.reverse(loaded_documents)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_document_input(document) do
    case safe_storage_read(document) do
      {:ok, data} ->
        {:ok, %{data: data, content_type: document.content_type}}

      {:error, reason} ->
        {:error, {:document_storage_error, document.filename, reason}}
    end
  end

  defp safe_storage_read(document) do
    Storage.read(document)
  rescue
    error -> {:error, Exception.message(error)}
  catch
    :exit, reason -> {:error, reason}
  end

  defp build_assertion_results(assertions, output) do
    Enum.map(assertions, fn assertion ->
      {passed, actual_value} = evaluate_assertion(output, assertion)
      format_assertion_result(assertion, passed, actual_value)
    end)
  end

  defp format_assertion_result(%{"type" => "json_field"} = assertion, passed, actual_value) do
    %{
      "type" => assertion["type"],
      "passed" => passed,
      "value" => %{
        "field" => assertion["field"],
        "expected" => assertion["expected"]
      },
      "actual_value" => actual_value
    }
  end

  defp format_assertion_result(assertion, passed, _actual_value) do
    %{
      "type" => assertion["type"],
      "passed" => passed,
      "value" => assertion["value"]
    }
  end

  defp successful_test_case_result(test_case_id, result, passed, assertion_results) do
    %{
      "test_case_id" => test_case_id,
      "passed" => passed,
      "output" => result.output,
      "assertion_results" => assertion_results,
      "cost_usd" => result.cost_usd,
      "latency_ms" => result.latency_ms
    }
  end

  defp failed_test_case_result(test_case_id, reason) do
    %{
      "test_case_id" => test_case_id,
      "passed" => false,
      "output" => error_message(reason),
      "assertion_results" => [],
      "cost_usd" => nil,
      "latency_ms" => nil
    }
  end

  defp error_message(:missing_api_key), do: "Missing API key"
  defp error_message({:auth_error, msg}), do: "Authentication error: #{msg}"

  defp error_message({:rate_limit, retry_after}) do
    "Rate limit exceeded#{if retry_after, do: ", retry after #{retry_after}s", else: ""}"
  end

  defp error_message({:invalid_request, msg}), do: "Invalid request: #{msg}"
  defp error_message({:api_error, status, msg}), do: "API error (#{status}): #{msg}"
  defp error_message({:network_error, err}), do: "Network error: #{inspect(err)}"

  defp error_message({:document_storage_error, filename, reason}),
    do: "Failed to load document #{filename}: #{format_storage_reason(reason)}"

  defp fetch_suite_run_result(%SuiteRun{results: results}, test_case_id) do
    case Enum.find(results, &(&1["test_case_id"] == test_case_id)) do
      nil -> {:error, :test_case_result_not_found}
      result -> {:ok, result}
    end
  end

  defp fetch_suite_test_case(suite_id, test_case_id) do
    query =
      from tc in TestCase,
        where: tc.id == ^test_case_id and tc.suite_id == ^suite_id

    case repo().one(query) do
      nil -> {:error, :test_case_not_found}
      test_case -> {:ok, repo().preload(test_case, :documents)}
    end
  end

  defp fetch_prompt_version(version_id) do
    case repo().get(PromptVersion, version_id) do
      nil -> {:error, :prompt_version_not_found}
      version -> {:ok, version}
    end
  end

  defp fetch_provider(provider_id) do
    case repo().get(Provider, provider_id) do
      nil -> {:error, :provider_not_found}
      provider -> {:ok, provider}
    end
  end

  defp merge_retry_metadata(result, existing_result) do
    retry_count = parse_retry_count(existing_result["retry_count"])

    Map.merge(result, %{
      "retry_count" => retry_count + 1,
      "retried_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    })
  end

  defp parse_retry_count(count) when is_integer(count), do: count

  defp parse_retry_count(count) when is_binary(count) do
    case Integer.parse(count) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp parse_retry_count(_count), do: 0

  defp replace_suite_run_result(results, test_case_id, replacement) do
    Enum.map(results, fn result ->
      if result["test_case_id"] == test_case_id, do: replacement, else: result
    end)
  end

  defp summarize_suite_results(results) do
    metrics =
      Enum.reduce(results, %{total_cost: Decimal.new("0"), total_latency: 0, successful: 0}, fn
        %{"cost_usd" => cost, "latency_ms" => latency}, acc
        when is_number(cost) and is_number(latency) ->
          %{
            total_cost: Decimal.add(acc.total_cost, decimal_from_number(cost)),
            total_latency: acc.total_latency + round(latency),
            successful: acc.successful + 1
          }

        _, acc ->
          acc
      end)

    passed = Enum.count(results, &(&1["passed"] == true))
    failed = length(results) - passed

    %{
      passed: passed,
      failed: failed,
      avg_cost_usd: average_cost(metrics),
      avg_latency_ms: average_latency(metrics)
    }
  end

  defp decimal_from_number(number) when is_float(number), do: Decimal.from_float(number)
  defp decimal_from_number(number) when is_integer(number), do: Decimal.new(number)

  defp average_cost(%{successful: successful}) when successful < 1, do: nil

  defp average_cost(%{total_cost: total_cost, successful: successful}) do
    Decimal.div(total_cost, successful)
  end

  defp average_latency(%{successful: successful}) when successful < 1, do: nil

  defp average_latency(%{total_latency: total_latency, successful: successful}) do
    round(total_latency / successful)
  end

  defp ensure_documents_loaded(%TestCase{documents: %NotLoaded{}} = test_case) do
    repo().preload(test_case, :documents)
  end

  defp ensure_documents_loaded(%TestCase{} = test_case), do: test_case

  defp render_template(template, variables) do
    Enum.reduce(variables, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end

  defp evaluate_assertion(output, %{"type" => "contains", "value" => value}) do
    {String.contains?(output, value), nil}
  end

  defp evaluate_assertion(output, %{"type" => "not_contains", "value" => value}) do
    {!String.contains?(output, value), nil}
  end

  defp evaluate_assertion(output, %{"type" => "regex", "value" => pattern}) do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        {Regex.match?(regex, output), nil}

      {:error, _} ->
        {false, nil}
    end
  end

  defp evaluate_assertion(output, %{"type" => "exact_match", "value" => value}) do
    {output == value, nil}
  end

  defp evaluate_assertion(output, %{
         "type" => "json_field",
         "field" => field,
         "expected" => expected
       }) do
    # Strip markdown code blocks if present (e.g., ```json ... ```)
    cleaned_output =
      output
      |> String.trim()
      |> String.replace(~r/^```json\s*/i, "")
      |> String.replace(~r/^```\s*/, "")
      |> String.replace(~r/```\s*$/, "")
      |> String.trim()

    case Jason.decode(cleaned_output) do
      {:ok, json} ->
        actual_value = get_in(json, String.split(field, "."))
        passed = compare_json_values(actual_value, expected)
        {passed, actual_value}

      {:error, _} ->
        {false, nil}
    end
  end

  # Fallback for unknown assertion types
  defp evaluate_assertion(_output, _assertion) do
    {false, nil}
  end

  # Safely compare JSON values without crashing on maps/lists
  defp compare_json_values(actual, expected) when is_map(actual) or is_list(actual) do
    # For complex types, compare as JSON strings
    Jason.encode!(actual) == Jason.encode!(expected)
  end

  defp compare_json_values(actual, expected) do
    # Scalars should preserve JSON semantics instead of coercing types.
    actual == expected
  end

  defp repo, do: Aludel.Repo.get()

  defp persist_document_externally(changeset) do
    document = Changeset.apply_changes(changeset)
    storage_key = Storage.storage_key(document.id, document.filename)
    storage_backend = Storage.backend_name()

    case Storage.put(storage_key, document.data, document.content_type) do
      {:ok, persisted_key} ->
        attrs =
          document_attrs(document)
          |> Map.put(:data, nil)
          |> Map.put(:storage_key, persisted_key)
          |> Map.put(:storage_backend, storage_backend)

        insert_changeset = TestCaseDocument.changeset(%TestCaseDocument{id: document.id}, attrs)

        case repo().insert(insert_changeset) do
          {:ok, stored_document} ->
            {:ok, stored_document}

          {:error, insert_changeset} ->
            _ = Storage.delete(persisted_key, storage_backend: storage_backend)
            {:error, insert_changeset}
        end

      {:error, reason} ->
        {:error, add_storage_error(changeset, reason)}
    end
  end

  defp document_attrs(document) do
    %{
      test_case_id: document.test_case_id,
      filename: document.filename,
      content_type: document.content_type,
      data: document.data,
      size_bytes: document.size_bytes,
      storage_key: document.storage_key,
      storage_backend: document.storage_backend
    }
  end

  defp add_storage_error(changeset, reason) do
    Changeset.add_error(changeset, :data, format_storage_reason(reason))
  end

  defp format_storage_reason(reason) when is_binary(reason), do: reason
  defp format_storage_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_storage_reason(reason), do: inspect(reason)
end
