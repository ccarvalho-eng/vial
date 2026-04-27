defmodule Aludel.Web.ExportControllerTest do
  use Aludel.Web.ConnCase, async: true

  import Aludel.EvalsFixtures
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Aludel.RunsFixtures

  describe "GET /runs/results/:id/export" do
    test "downloads a run result payload as JSON", %{conn: conn} do
      run = run_fixture(%{name: "Export Run"})
      provider = provider_fixture(%{name: "Export Provider"})

      result =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider.id,
          output: "Callback output",
          status: :completed,
          input_tokens: nil,
          output_tokens: nil,
          latency_ms: nil,
          cost_usd: nil,
          metadata: %{"trace_id" => "trace-123"}
        })

      conn = get(conn, "/runs/results/#{result.id}/export")

      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/json"
      assert get_resp_header(conn, "cache-control") == ["no-store, max-age=0"]
      assert get_resp_header(conn, "pragma") == ["no-cache"]
      assert get_resp_header(conn, "expires") == ["0"]

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"run-result-#{result.id}.json\""
             ]

      payload = Jason.decode!(conn.resp_body)

      assert payload["type"] == "run_result"
      assert payload["run"]["id"] == run.id
      assert payload["run"]["name"] == "Export Run"
      assert payload["result"]["id"] == result.id
      assert payload["result"]["provider"]["id"] == provider.id
      assert payload["result"]["provider"]["name"] == "Export Provider"
      assert payload["result"]["status"] == "completed"
      assert payload["result"]["output"] == "Callback output"
      assert payload["result"]["metadata"]["trace_id"] == "trace-123"
    end
  end

  describe "GET /suites/runs/:id/export" do
    test "downloads a suite run payload as JSON", %{conn: conn} do
      prompt = prompt_fixture_with_version(%{name: "Export Prompt"})
      prompt = Aludel.Prompts.get_prompt_with_versions!(prompt.id)
      version = hd(prompt.versions)
      suite = suite_fixture(%{name: "Export Suite", prompt_id: prompt.id})
      provider = provider_fixture(%{name: "Suite Provider"})
      test_case = test_case_fixture(%{suite_id: suite.id})

      suite_run =
        suite_run_fixture(%{
          suite_id: suite.id,
          prompt_version_id: version.id,
          provider_id: provider.id,
          passed: 1,
          failed: 0,
          avg_cost_usd: Decimal.new("0.0010"),
          avg_latency_ms: 250,
          results: [
            %{
              "test_case_id" => test_case.id,
              "passed" => true,
              "output" => "Structured output",
              "assertion_results" => [
                %{"type" => "contains", "passed" => true, "value" => "Structured"}
              ],
              "cost_usd" => 0.001,
              "latency_ms" => 250,
              "retry_count" => 1,
              "retried_at" => "2026-04-26T13:00:00Z"
            }
          ]
        })

      conn = get(conn, "/suites/runs/#{suite_run.id}/export")

      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/json"
      assert get_resp_header(conn, "cache-control") == ["no-store, max-age=0"]
      assert get_resp_header(conn, "pragma") == ["no-cache"]
      assert get_resp_header(conn, "expires") == ["0"]

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"suite-run-#{suite_run.id}.json\""
             ]

      payload = Jason.decode!(conn.resp_body)

      assert payload["type"] == "suite_run"
      assert payload["suite_run"]["id"] == suite_run.id
      assert payload["suite_run"]["suite"]["id"] == suite.id
      assert payload["suite_run"]["suite"]["name"] == "Export Suite"
      assert payload["suite_run"]["provider"]["id"] == provider.id
      assert payload["suite_run"]["provider"]["name"] == "Suite Provider"
      assert payload["suite_run"]["summary"]["passed"] == 1
      assert payload["suite_run"]["summary"]["failed"] == 0
      assert payload["suite_run"]["summary"]["avg_cost_usd"] == 0.001

      assert payload["suite_run"]["results"] == [
               %{
                 "assertion_results" => [
                   %{"passed" => true, "type" => "contains", "value" => "Structured"}
                 ],
                 "cost_usd" => 0.001,
                 "error" => nil,
                 "input_tokens" => nil,
                 "latency_ms" => 250,
                 "output" => "Structured output",
                 "output_tokens" => nil,
                 "passed" => true,
                 "retry_count" => 1,
                 "retried_at" => "2026-04-26T13:00:00Z",
                 "status" => "passed",
                 "test_case_id" => test_case.id
               }
             ]
    end
  end
end
