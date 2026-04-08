defmodule Aludel.Providers do
  @moduledoc """
  Context for managing AI provider configurations.
  """

  alias Aludel.Providers.Provider
  alias Ecto.Changeset

  @doc """
  Lists all providers in the system.
  """
  @spec list_providers() :: [Provider.t()]
  def list_providers do
    repo().all(Provider)
  end

  @doc """
  Gets a provider by ID, raising if not found.
  """
  @spec get_provider!(binary()) :: Provider.t()
  def get_provider!(id) do
    repo().get!(Provider, id)
  end

  @doc """
  Creates a new provider.
  """
  @spec create_provider(map()) ::
          {:ok, Provider.t()} | {:error, Changeset.t()}
  def create_provider(attrs \\ %{}) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing provider.
  """
  @spec update_provider(Provider.t(), map()) ::
          {:ok, Provider.t()} | {:error, Changeset.t()}
  def update_provider(%Provider{} = provider, attrs) do
    provider
    |> Provider.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a provider.
  """
  @spec delete_provider(Provider.t()) ::
          {:ok, Provider.t()} | {:error, Changeset.t()}
  def delete_provider(%Provider{} = provider) do
    repo().delete(provider)
  end

  @doc """
  Returns a changeset for tracking provider changes.
  """
  @spec change_provider(Provider.t(), map()) :: Changeset.t()
  def change_provider(%Provider{} = provider, attrs \\ %{}) do
    Provider.changeset(provider, attrs)
  end

  @doc """
  Fetches available models for a given provider type.
  """
  @spec fetch_models(nil | binary() | atom()) :: [map()]
  def fetch_models(nil), do: []
  def fetch_models(""), do: []

  def fetch_models(provider_type) when is_binary(provider_type) do
    fetch_model_groups(provider_type).active
  end

  def fetch_models(provider_type) when is_atom(provider_type) do
    fetch_model_groups(provider_type).active
  end

  @doc """
  Fetches models grouped into active and deprecated sets.
  """
  @spec fetch_model_groups(nil | binary() | atom()) :: %{
          active: [map()],
          deprecated: [map()]
        }
  def fetch_model_groups(nil), do: %{active: [], deprecated: []}
  def fetch_model_groups(""), do: %{active: [], deprecated: []}

  def fetch_model_groups(provider_type) when is_binary(provider_type) do
    case provider_type do
      "openai" -> fetch_model_groups(:openai)
      "anthropic" -> fetch_model_groups(:anthropic)
      "ollama" -> fetch_model_groups(:ollama)
      "google" -> fetch_model_groups(:google)
      _ -> %{active: [], deprecated: []}
    end
  end

  def fetch_model_groups(provider_type) when is_atom(provider_type) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.Apply
    LLMDB
    |> apply(:models, [])
    |> Enum.filter(&(&1.provider == provider_type))
    |> Enum.map(&normalize_model/1)
    |> group_models()
  rescue
    _ -> %{active: [], deprecated: []}
  end

  @doc false
  @spec group_models([map()]) :: %{active: [map()], deprecated: [map()]}
  def group_models(models) when is_list(models) do
    models
    |> Enum.sort_by(fn %{name: name, id: id} ->
      {String.downcase(name), String.downcase(id)}
    end)
    |> Enum.group_by(& &1.deprecated)
    |> then(fn grouped ->
      %{active: Map.get(grouped, false, []), deprecated: Map.get(grouped, true, [])}
    end)
  end

  defp normalize_model(%{id: id} = model) do
    name =
      case Map.get(model, :name) do
        nil -> id
        "" -> id
        value -> value
      end

    %{id: id, name: name, deprecated: Map.get(model, :deprecated, false)}
  end

  defp repo, do: Aludel.Repo.get()
end
