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
  end
end
