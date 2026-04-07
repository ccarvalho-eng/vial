defmodule Aludel.Web.ProviderLive.NewTest do
  use Aludel.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Aludel.ProvidersFixtures

  alias Aludel.Providers

  describe "new provider page" do
    test "renders the provider form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/providers/new")

      assert has_element?(view, "#provider-form")
      assert has_element?(view, "#provider-form input[name='provider[name]']")
      assert has_element?(view, "#provider-form select[name='provider[model_selection]']")
    end

    test "shows custom input when custom model is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/providers/new")

      html =
        view
        |> form("#provider-form", provider: %{provider: "openai", model_selection: "custom"})
        |> render_change()

      assert html =~ "Custom model name"
    end

    test "creates provider with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/providers/new")

      view
      |> form("#provider-form", provider: valid_provider_params())
      |> render_submit()

      assert_redirect(view, "/providers")

      [provider] = Providers.list_providers()
      assert provider.name == "Configured Provider"
      assert provider.provider == :openai
      assert provider.model == "gpt-4.1"
      assert provider.config == %{"temperature" => 0.2, "max_tokens" => 512}
    end

    test "shows validation errors for invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/providers/new")

      view
      |> form("#provider-form",
        provider: %{
          name: "",
          provider: "",
          model: ""
        }
      )
      |> render_submit()

      assert has_element?(view, "#provider_name.input-error")
      assert has_element?(view, "#provider_provider.select-error")
      assert has_element?(view, "#provider_model.input-error")
    end
  end

  describe "provider editing" do
    test "keeps an existing model selectable during edit", %{conn: conn} do
      provider =
        provider_fixture(%{
          name: "Existing Provider",
          provider: :openai,
          model: "gpt-4o"
        })

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      assert has_element?(view, "#provider-form")
      assert has_element?(view, "#provider-form select[name='provider[model_selection]']")
    end

    test "updates provider with valid data", %{conn: conn} do
      provider = provider_fixture()

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      view
      |> form("#provider-form",
        provider: %{
          name: "Updated Provider",
          provider: "anthropic",
          model: "claude-3-7-sonnet",
          config: ~s({"temperature":0.4})
        }
      )
      |> render_submit()

      assert_redirect(view, "/providers")

      updated_provider = Providers.get_provider!(provider.id)
      assert updated_provider.name == "Updated Provider"
      assert updated_provider.provider == :anthropic
      assert updated_provider.model == "claude-3-7-sonnet"
      assert updated_provider.config == %{"temperature" => 0.4}
    end

    test "keeps provider unchanged when invalid data is submitted", %{conn: conn} do
      provider = provider_fixture(%{name: "Existing Provider", model: "gpt-4o"})

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      view
      |> form("#provider-form",
        provider: %{
          name: "",
          provider: "",
          model: ""
        }
      )
      |> render_submit()

      assert has_element?(view, "#provider_name.input-error")
      assert has_element?(view, "#provider_provider.select-error")
      assert has_element?(view, "#provider_model.input-error")

      reloaded_provider = Providers.get_provider!(provider.id)
      assert reloaded_provider.name == "Existing Provider"
      assert reloaded_provider.model == "gpt-4o"
    end
  end

  defp valid_provider_params do
    %{
      name: "Configured Provider",
      provider: "openai",
      model: "gpt-4.1",
      config: ~s({"temperature":0.2,"max_tokens":512})
    }
  end
end
