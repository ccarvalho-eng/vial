defmodule Vial.Providers do
  @moduledoc """
  Context for managing AI provider configurations.
  """

  alias Vial.Providers.Provider
  alias Vial.Repo

  @doc """
  Lists all providers in the system.
  """
  @spec list_providers() :: [Provider.t()]
  def list_providers do
    Repo.all(Provider)
  end

  @doc """
  Gets a provider by ID, raising if not found.
  """
  @spec get_provider!(binary()) :: Provider.t()
  def get_provider!(id) do
    Repo.get!(Provider, id)
  end

  @doc """
  Creates a new provider.
  """
  @spec create_provider(map()) ::
          {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def create_provider(attrs \\ %{}) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing provider.
  """
  @spec update_provider(Provider.t(), map()) ::
          {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def update_provider(%Provider{} = provider, attrs) do
    provider
    |> Provider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a provider.
  """
  @spec delete_provider(Provider.t()) ::
          {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def delete_provider(%Provider{} = provider) do
    Repo.delete(provider)
  end

  @doc """
  Returns a changeset for tracking provider changes.
  """
  @spec change_provider(Provider.t(), map()) :: Ecto.Changeset.t()
  def change_provider(%Provider{} = provider, attrs \\ %{}) do
    Provider.changeset(provider, attrs)
  end
end
