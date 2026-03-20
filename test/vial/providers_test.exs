defmodule Vial.ProvidersTest do
  use Vial.DataCase, async: true

  alias Vial.Providers

  describe "providers" do
    test "list_providers/0 returns all providers" do
      provider = provider_fixture()
      assert Providers.list_providers() == [provider]
    end

    test "get_provider!/1 returns the provider with given id" do
      provider = provider_fixture()
      assert Providers.get_provider!(provider.id) == provider
    end

    test "create_provider/1 with valid data creates a provider" do
      attrs = %{
        name: "OpenAI GPT-4o",
        provider: :openai,
        model: "gpt-4o",
        config: %{"temperature" => 0.7, "max_tokens" => 1000}
      }

      assert {:ok, provider} = Providers.create_provider(attrs)
      assert provider.name == "OpenAI GPT-4o"
      assert provider.provider == :openai
      assert provider.model == "gpt-4o"
      assert provider.config == %{"temperature" => 0.7, "max_tokens" => 1000}
    end

    test "create_provider/1 with invalid provider enum returns error" do
      attrs = %{
        name: "Invalid Provider",
        provider: :invalid,
        model: "test-model",
        config: %{}
      }

      assert {:error, changeset} = Providers.create_provider(attrs)
      assert "is invalid" in errors_on(changeset).provider
    end

    test "create_provider/1 without name returns error" do
      attrs = %{
        provider: :openai,
        model: "gpt-4o",
        config: %{}
      }

      assert {:error, changeset} = Providers.create_provider(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "create_provider/1 without provider returns error" do
      attrs = %{
        name: "Test Provider",
        model: "gpt-4o",
        config: %{}
      }

      assert {:error, changeset} = Providers.create_provider(attrs)
      assert "can't be blank" in errors_on(changeset).provider
    end

    test "create_provider/1 without model returns error" do
      attrs = %{
        name: "Test Provider",
        provider: :openai,
        config: %{}
      }

      assert {:error, changeset} = Providers.create_provider(attrs)
      assert "can't be blank" in errors_on(changeset).model
    end

    test "create_provider/1 with JSONB config storage" do
      attrs = %{
        name: "Anthropic Claude",
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        config: %{
          "temperature" => 0.5,
          "max_tokens" => 2000,
          "top_p" => 1.0
        }
      }

      assert {:ok, provider} = Providers.create_provider(attrs)

      assert provider.config == %{
               "temperature" => 0.5,
               "max_tokens" => 2000,
               "top_p" => 1.0
             }
    end

    test "update_provider/2 with valid data updates the provider" do
      provider = provider_fixture()

      update_attrs = %{
        name: "Updated Name",
        model: "updated-model",
        config: %{"temperature" => 0.9}
      }

      assert {:ok, updated} = Providers.update_provider(provider, update_attrs)
      assert updated.name == "Updated Name"
      assert updated.model == "updated-model"
      assert updated.config == %{"temperature" => 0.9}
    end

    test "update_provider/2 with invalid data returns error" do
      provider = provider_fixture()
      assert {:error, changeset} = Providers.update_provider(provider, %{name: nil})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "delete_provider/1 deletes the provider" do
      provider = provider_fixture()
      assert {:ok, _} = Providers.delete_provider(provider)
      assert_raise Ecto.NoResultsError, fn -> Providers.get_provider!(provider.id) end
    end

    test "change_provider/1 returns a provider changeset" do
      provider = provider_fixture()
      assert %Ecto.Changeset{} = Providers.change_provider(provider)
    end

    test "change_provider/2 returns a provider changeset with changes" do
      provider = provider_fixture()
      changeset = Providers.change_provider(provider, %{name: "New Name"})
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.name == "New Name"
    end
  end
end
