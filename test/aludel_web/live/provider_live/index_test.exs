defmodule Aludel.Web.ProviderLive.IndexTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.ProvidersFixtures

  describe "provider list" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/providers")

      assert html =~ "Providers"
    end

    test "displays list of providers", %{conn: conn} do
      _provider1 = provider_fixture(%{name: "OpenAI GPT-4"})
      _provider2 = provider_fixture(%{name: "Claude Sonnet"})

      {:ok, _view, html} = live(conn, "/providers")

      assert html =~ "OpenAI GPT-4"
      assert html =~ "Claude Sonnet"
    end

    test "shows new provider button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/providers")

      assert html =~ "New Provider" or html =~ "Add Provider"
    end

    test "displays provider details", %{conn: conn} do
      _provider =
        provider_fixture(%{
          name: "Test Provider",
          provider: :openai,
          model: "gpt-4o"
        })

      {:ok, _view, html} = live(conn, "/providers")

      assert html =~ "Test Provider"
      assert html =~ "gpt-4o"
    end

    test "displays Google provider with Google icon", %{conn: conn} do
      _provider =
        provider_fixture(%{
          name: "Gemini Flash",
          provider: :google,
          model: "gemini-2.5-flash"
        })

      {:ok, _view, html} = live(conn, "/providers")

      assert html =~ "Gemini Flash"
      assert html =~ "gemini-icon.svg"
    end
  end

  describe "delete functionality" do
    test "deletes provider successfully", %{conn: conn} do
      provider = provider_fixture(%{name: "Delete Me"})

      {:ok, view, _html} = live(conn, "/providers")

      html = render_click(view, "delete", %{"id" => provider.id})

      assert html =~ "Provider deleted successfully"
      refute html =~ "Delete Me"
    end

    test "refreshes provider list after deletion", %{conn: conn} do
      provider1 = provider_fixture(%{name: "Provider 1"})
      _provider2 = provider_fixture(%{name: "Provider 2"})

      {:ok, view, _html} = live(conn, "/providers")

      assert render(view) =~ "Provider 1"
      assert render(view) =~ "Provider 2"

      html = render_click(view, "delete", %{"id" => provider1.id})

      refute html =~ "Provider 1"
      assert html =~ "Provider 2"
    end
  end
end
