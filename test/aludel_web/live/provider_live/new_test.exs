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
      |> form("#provider-form", provider: %{provider: "openai", model_selection: "custom"})
      |> render_change()

      view
      |> form("#provider-form",
        provider: %{
          name: "Configured Provider",
          provider: "openai",
          model_selection: "custom",
          model_custom: "gpt-4.1",
          config: ~s({"temperature":0.2,"max_tokens":512})
        }
      )
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
          model_selection: ""
        }
      )
      |> render_submit()

      assert has_element?(view, "#provider_name.input-error")
      assert has_element?(view, "#provider_provider.select-error")
      refute has_element?(view, "#provider_model_selection.select-error")
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

    test "loads unknown saved model as custom during edit", %{conn: conn} do
      provider =
        provider_fixture(%{
          name: "Custom Provider",
          provider: :openai,
          model: "my-custom-model"
        })

      {:ok, view, html} = live(conn, "/providers/#{provider.id}/edit")

      assert html =~ "Custom model name"
      assert has_element?(view, "#provider_model_custom[value='my-custom-model']")
      assert has_element?(view, "#provider_model_selection option[value='custom'][selected]")
    end

    test "updates provider with valid data", %{conn: conn} do
      provider = provider_fixture()

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      view
      |> form("#provider-form", provider: %{provider: "anthropic", model_selection: "custom"})
      |> render_change()

      view
      |> form("#provider-form",
        provider: %{
          name: "Updated Provider",
          provider: "anthropic",
          model_selection: "custom",
          model_custom: "claude-3-7-sonnet",
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

    test "clears stale model selection when provider changes", %{conn: conn} do
      provider = provider_fixture(%{provider: :openai, model: "gpt-4o"})

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      render_change(
        view,
        :validate,
        %{provider: %{provider: "anthropic", model_selection: "gpt-4o"}}
      )

      refute has_element?(view, "#provider_model_selection option[value='gpt-4o'][selected]")

      view
      |> form("#provider-form",
        provider: %{
          provider: "anthropic",
          model_selection: "claude-3-haiku-20240307",
          name: "OpenAI GPT-4o",
          config: ~s({})
        }
      )
      |> render_submit()

      reloaded_provider = Providers.get_provider!(provider.id)
      assert reloaded_provider.provider == :anthropic
      assert reloaded_provider.model == "claude-3-haiku-20240307"
    end

    test "keeps provider unchanged when invalid data is submitted", %{conn: conn} do
      provider = provider_fixture(%{name: "Existing Provider", model: "gpt-4o"})

      {:ok, view, _html} = live(conn, "/providers/#{provider.id}/edit")

      view
      |> form("#provider-form",
        provider: %{
          name: "",
          provider: "",
          model_selection: ""
        }
      )
      |> render_submit()

      assert has_element?(view, "#provider_name.input-error")
      assert has_element?(view, "#provider_provider.select-error")
      refute has_element?(view, "#provider_model_selection.select-error")

      reloaded_provider = Providers.get_provider!(provider.id)
      assert reloaded_provider.name == "Existing Provider"
      assert reloaded_provider.model == "gpt-4o"
    end
  end
end
