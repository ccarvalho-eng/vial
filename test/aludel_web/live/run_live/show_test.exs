defmodule Aludel.Web.RunLive.ShowTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.RunsFixtures
  import Aludel.ProvidersFixtures

  describe "show run" do
    setup do
      run = run_fixture(%{name: "Test Run"})
      provider1 = provider_fixture(%{name: "OpenAI"})
      provider2 = provider_fixture(%{name: "Anthropic"})

      result1 =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider1.id,
          output: "Hello from OpenAI",
          status: :completed,
          input_tokens: 10,
          output_tokens: 20,
          latency_ms: 500,
          cost_usd: 0.001
        })

      result2 =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider2.id,
          output: "Hello from Anthropic",
          status: :completed,
          input_tokens: 12,
          output_tokens: 18,
          latency_ms: 450,
          cost_usd: 0.0015
        })

      %{
        run: run,
        provider1: provider1,
        provider2: provider2,
        result1: result1,
        result2: result2
      }
    end

    test "mounts and displays run details", %{conn: conn, run: run} do
      {:ok, _view, html} = live(conn, "/runs/#{run.id}")

      assert html =~ "Test Run"
      assert html =~ "user"
      assert html =~ "Alice"
    end

    test "displays all provider results", %{
      conn: conn,
      run: run,
      provider1: provider1,
      provider2: provider2
    } do
      {:ok, _view, html} = live(conn, "/runs/#{run.id}")

      assert html =~ provider1.name
      assert html =~ provider2.name
      assert html =~ "Hello from OpenAI"
      assert html =~ "Hello from Anthropic"
    end

    test "displays result metrics", %{conn: conn, run: run} do
      {:ok, _view, html} = live(conn, "/runs/#{run.id}")

      assert html =~ "10"
      assert html =~ "20"
      assert html =~ "500"
      assert html =~ "0.001"
    end

    test "subscribes to pubsub for real-time updates", %{
      conn: conn,
      run: run
    } do
      {:ok, view, _html} = live(conn, "/runs/#{run.id}")

      provider3 = provider_fixture(%{name: "Cohere"})

      result3 =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider3.id,
          output: "",
          status: :pending
        })

      {:ok, _updated_result} =
        Aludel.Runs.update_run_result(result3, %{
          output: "Streaming update from Cohere",
          status: :completed
        })

      Phoenix.PubSub.broadcast(
        Aludel.PubSub,
        "run:#{run.id}",
        {:run_result_update, result3.id, :completed, "Streaming update from Cohere"}
      )

      html = render(view)
      assert html =~ provider3.name
      assert html =~ "Streaming update from Cohere"
    end

    test "handles running status updates", %{
      conn: conn,
      run: run
    } do
      {:ok, view, _html} = live(conn, "/runs/#{run.id}")

      provider3 = provider_fixture(%{name: "Cohere"})

      result3 =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider3.id,
          output: "",
          status: :pending
        })

      {:ok, _updated_result} =
        Aludel.Runs.update_run_result(result3, %{
          output: "Partial",
          status: :running,
          started_at: DateTime.utc_now()
        })

      Phoenix.PubSub.broadcast(
        Aludel.PubSub,
        "run:#{run.id}",
        {:run_result_update, result3.id, :running, "Partial"}
      )

      html = render(view)
      assert html =~ "Partial"
      assert html =~ "running"
    end

    test "displays error status for failed results", %{conn: conn} do
      run = run_fixture(%{name: "Error Run"})
      provider = provider_fixture(%{name: "FailProvider"})

      _result =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider.id,
          status: :error,
          error: "API call failed"
        })

      {:ok, _view, html} = live(conn, "/runs/#{run.id}")

      assert html =~ "error"
      assert html =~ "API call failed"
    end

    test "renders missing metrics as N/A and shows callback metadata", %{conn: conn} do
      run = run_fixture(%{name: "Callback Run"})
      provider = provider_fixture(%{name: "Callback Provider"})

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
          metadata: %{
            "trace_id" => "trace-123",
            "job_id" => "job-456"
          }
        })

      {:ok, view, html} = live(conn, "/runs/#{run.id}")

      assert html =~ "N/A / N/A"
      assert html =~ "N/A"
      assert has_element?(view, "#run-result-metadata-#{result.id}")
      assert has_element?(view, "#run-result-metadata-#{result.id} summary", "Callback metadata")

      assert has_element?(
               view,
               "#run-result-metadata-#{result.id} pre",
               "\"trace_id\": \"trace-123\""
             )

      assert has_element?(
               view,
               "#run-result-metadata-#{result.id} pre",
               "\"job_id\": \"job-456\""
             )
    end

    test "shows copy actions for successful outputs", %{conn: conn, run: run, result1: result1} do
      {:ok, view, _html} = live(conn, "/runs/#{run.id}")

      assert has_element?(view, "#run-result-output-#{result1.id}", "Hello from OpenAI")
      assert has_element?(view, "#copy-run-output-#{result1.id}", "Copy output")
    end

    test "shows copy actions for failed errors", %{conn: conn} do
      run = run_fixture(%{name: "Copy Error Run"})
      provider = provider_fixture(%{name: "FailProvider"})

      result =
        run_result_fixture(%{
          run_id: run.id,
          provider_id: provider.id,
          status: :error,
          error: "API call failed"
        })

      {:ok, view, _html} = live(conn, "/runs/#{run.id}")

      assert has_element?(view, "#run-result-error-#{result.id}", "API call failed")
      assert has_element?(view, "#copy-run-error-#{result.id}", "Copy error")
    end

    test "raises 404 for non-existent run", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, "/runs/#{fake_id}")
      end
    end
  end
end
