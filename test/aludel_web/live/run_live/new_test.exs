defmodule Aludel.Web.RunLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.PromptsFixtures
  import Aludel.ProvidersFixtures

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
      conn: conn,
      version: version,
      provider1: provider1,
      provider2: provider2
    } do
      {:ok, view, _html} =
        live(conn, "/runs/new?version=#{version.id}")

      result =
        view
        |> form("#run-form",
          run: %{
            name: "Test Run",
            variable_values: %{
              "user" => "Alice",
              "topic" => "Elixir"
            },
            provider_ids: [provider1.id, provider2.id]
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert String.starts_with?(path, "/runs/")
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
