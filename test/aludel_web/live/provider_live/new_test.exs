defmodule Aludel.Web.ProviderLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.ProvidersFixtures

  describe "new provider page" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/providers/new")

      assert html =~ "New Provider"
    end

    test "shows provider form fields", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/providers/new")

      assert html =~ "Name"
      assert html =~ "Provider"
      assert html =~ "Model"
    end

    test "shows create button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/providers/new")

      assert html =~ "Create Provider"
    end
  end

  describe "provider editing" do
    test "loads existing provider for editing", %{conn: conn} do
      provider = provider_fixture(%{name: "Existing Provider"})

      {:ok, _view, html} = live(conn, "/providers/#{provider.id}/edit")

      assert html =~ "Edit Provider"
      assert html =~ "Existing Provider"
    end

    test "displays provider details in form", %{conn: conn} do
      provider =
        provider_fixture(%{
          name: "Test Provider",
          provider: :openai,
          model: "gpt-4o"
        })

      {:ok, _view, html} = live(conn, "/providers/#{provider.id}/edit")

      assert html =~ "Test Provider"
      assert html =~ "gpt-4o"
    end
  end
end
