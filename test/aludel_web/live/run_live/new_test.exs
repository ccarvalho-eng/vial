defmodule Aludel.Web.RunLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures
  import Mox

  alias Aludel.Prompts

  describe "configure run" do
    setup do
      prompt = prompt_fixture(%{name: "Test Prompt"})

      {:ok, version} =
        Prompts.create_prompt_version(
          prompt,
          "Hello {{user}}, welcome to {{topic}}"
        )

      provider1 = provider_fixture(%{name: "Provider 1"})
      provider2 = provider_fixture(%{name: "Provider 2"})

      %{
        prompt: prompt,
        version: version,
        provider1: provider1,
        provider2: provider2
      }
    end

    test "renders run configuration form with prompt version", %{
      conn: conn,
      version: version,
      prompt: prompt
    } do
      {:ok, _view, html} =
        live(conn, "/runs/new?version=#{version.id}")

      assert html =~ "Configure Run"
      assert html =~ prompt.name
      assert html =~ "v#{version.version}"
    end

    test "shows the app callback execution mode label when configured", %{
      conn: conn,
      version: version
    } do
      original_mode = Application.get_env(:aludel, :execution_mode)

      Application.put_env(:aludel, :execution_mode, :callback)

      on_exit(fn ->
        Application.put_env(:aludel, :execution_mode, original_mode)
      end)

      {:ok, _view, html} = live(conn, "/runs/new?version=#{version.id}")

      assert html =~ "Execution Mode"
      assert html =~ "App Callback"
    end

    test "displays form inputs for each variable", %{
      conn: conn,
      version: version
    } do
      {:ok, _view, html} =
        live(conn, "/runs/new?version=#{version.id}")

      assert html =~ "user"
      assert html =~ "topic"
    end

    test "displays provider checkboxes", %{
      conn: conn,
      version: version,
      provider1: provider1,
      provider2: provider2
    } do
      {:ok, _view, html} =
        live(conn, "/runs/new?version=#{version.id}")

      assert html =~ provider1.name
      assert html =~ provider2.name
    end

    test "keeps selected providers checked after validation", %{
      conn: conn,
      version: version,
      provider1: provider1
    } do
      {:ok, view, _html} =
        live(conn, "/runs/new?version=#{version.id}")

      view
      |> form("#run-form",
        run: %{
          variable_values: %{"user" => "Alice", "topic" => "Elixir"},
          provider_ids: [provider1.id]
        }
      )
      |> render_change()

      assert has_element?(
               view,
               ~s(input#provider-#{provider1.id}[name="run[provider_ids][]"][checked])
             )
    end

    test "creates run and executes with selected providers", %{
      version: version,
      provider1: provider1,
      provider2: provider2
    } do
      mock_response = %{content: "Hello Alice", input_tokens: 5, output_tokens: 10}

      expect(Aludel.Interfaces.HttpClientMock, :request, 2, fn _model, _prompt, _opts ->
        {:ok, mock_response}
      end)

      run =
        case Aludel.Runs.create_run(%{
               prompt_version_id: version.id,
               variable_values: %{"user" => "Alice", "topic" => "Elixir"},
               name: "Test Run"
             }) do
          {:ok, run} -> run
          {:error, changeset} -> flunk(inspect(changeset.errors))
        end

      run = %{run | prompt_version: version}

      assert {:ok, execution} = Aludel.Runs.execute_run(run, [provider1, provider2])
      assert length(execution.run.run_results) == 2
    end

    test "validates required variable values", %{
      conn: conn,
      version: version,
      provider1: provider1
    } do
      {:ok, view, _html} =
        live(conn, "/runs/new?version=#{version.id}")

      html =
        view
        |> form("#run-form",
          run: %{
            variable_values: %{"user" => ""},
            provider_ids: [provider1.id]
          }
        )
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "validates at least one provider is selected", %{
      conn: conn,
      version: version
    } do
      {:ok, view, _html} =
        live(conn, "/runs/new?version=#{version.id}")

      html =
        view
        |> form("#run-form",
          run: %{
            variable_values: %{"user" => "Alice", "topic" => "Elixir"},
            provider_ids: []
          }
        )
        |> render_submit()

      assert html =~ "at least one provider"
    end

    test "shows template preview", %{conn: conn, version: version} do
      {:ok, _view, html} =
        live(conn, "/runs/new?version=#{version.id}")

      assert html =~ version.template
    end

    test "displays cancel link back to prompt show page", %{
      conn: conn,
      version: version,
      prompt: prompt
    } do
      {:ok, _view, html} =
        live(conn, "/runs/new?version=#{version.id}")

      assert html =~ "/prompts/#{prompt.id}"
    end
  end
end
