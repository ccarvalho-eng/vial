defmodule Aludel.Web.ExportController do
  @moduledoc false

  use Phoenix.Controller, formats: [:json]

  import Plug.Conn

  alias Aludel.Evals
  alias Aludel.Runs
  alias Decimal

  def run_result(conn, %{"id" => id}) do
    payload =
      id
      |> Runs.get_run_result_for_export!()
      |> serialize_run_result_export()

    send_json_download(conn, payload, "run-result-#{id}.json")
  end

  def suite_run(conn, %{"id" => id}) do
    payload =
      id
      |> Evals.get_suite_run_for_export!()
      |> serialize_suite_run_export()

    send_json_download(conn, payload, "suite-run-#{id}.json")
  end

  defp send_json_download(conn, payload, filename) do
    encoded_payload = Jason.encode!(payload, pretty: true)

    conn
    |> put_resp_header("cache-control", "no-store, max-age=0")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> send_download({:binary, encoded_payload},
      filename: filename,
      content_type: "application/json"
    )
  end

  defp serialize_run_result_export(result) do
    %{
      type: "run_result",
      exported_at: iso8601(DateTime.utc_now()),
      run: %{
        id: result.run.id,
        name: result.run.name,
        status: to_string(result.run.status),
        prompt_version_id: result.run.prompt_version_id,
        prompt_id: result.run.prompt_version.prompt.id,
        prompt_name: result.run.prompt_version.prompt.name,
        variable_values: result.run.variable_values,
        started_at: iso8601(result.run.started_at),
        completed_at: iso8601(result.run.completed_at)
      },
      result: %{
        id: result.id,
        provider: serialize_provider(result.provider),
        status: to_string(result.status),
        output: result.output,
        error: result.error,
        input_tokens: result.input_tokens,
        output_tokens: result.output_tokens,
        latency_ms: result.latency_ms,
        cost_usd: result.cost_usd,
        metadata: result.metadata,
        started_at: iso8601(result.started_at),
        completed_at: iso8601(result.completed_at),
        inserted_at: iso8601(result.inserted_at),
        updated_at: iso8601(result.updated_at)
      }
    }
  end

  defp serialize_suite_run_export(suite_run) do
    %{
      type: "suite_run",
      exported_at: iso8601(DateTime.utc_now()),
      suite_run: %{
        id: suite_run.id,
        suite: %{
          id: suite_run.suite.id,
          name: suite_run.suite.name
        },
        prompt_version: %{
          id: suite_run.prompt_version.id,
          version: suite_run.prompt_version.version,
          prompt_id: suite_run.prompt_version.prompt_id
        },
        provider: serialize_provider(suite_run.provider),
        summary: %{
          passed: suite_run.passed,
          failed: suite_run.failed,
          total: suite_run.passed + suite_run.failed,
          avg_cost_usd: decimal_to_float(suite_run.avg_cost_usd),
          avg_latency_ms: suite_run.avg_latency_ms
        },
        results: Enum.map(suite_run.results, &serialize_suite_result/1),
        inserted_at: iso8601(suite_run.inserted_at),
        updated_at: iso8601(suite_run.updated_at)
      }
    }
  end

  defp serialize_suite_result(result) do
    %{
      test_case_id: result["test_case_id"],
      status: if(result["passed"], do: "passed", else: "failed"),
      passed: result["passed"],
      output: result["output"],
      error: suite_result_error(result),
      input_tokens: result["input_tokens"],
      output_tokens: result["output_tokens"],
      latency_ms: result["latency_ms"],
      cost_usd: result["cost_usd"],
      assertion_results: Map.get(result, "assertion_results", []),
      retry_count: result["retry_count"],
      retried_at: result["retried_at"]
    }
  end

  defp serialize_provider(provider) do
    %{
      id: provider.id,
      name: provider.name,
      type: to_string(provider.provider),
      model: provider.model
    }
  end

  defp suite_result_error(%{"passed" => false} = result) do
    assertion_results = Map.get(result, "assertion_results", [])

    if assertion_results == [], do: result["output"], else: nil
  end

  defp suite_result_error(_result), do: nil

  defp decimal_to_float(nil), do: nil
  defp decimal_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
