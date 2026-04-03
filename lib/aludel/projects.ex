defmodule Aludel.Projects do
  @moduledoc """
  Context for managing projects that organize prompts and test suites.
  """

  import Ecto.Query

  alias Aludel.Projects.Project

  @doc """
  Returns the list of projects with prompts and suites preloaded.

  Projects are ordered alphabetically by name.
  Suites are preloaded with their associated prompt.
  """
  @spec list_projects() :: [Project.t()]
  def list_projects do
    from(p in Project,
      order_by: p.name,
      preload: [:prompts, suites: :prompt]
    )
    |> repo().all()
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.
  """
  @spec get_project!(binary()) :: Project.t()
  def get_project!(id), do: repo().get!(Project, id)

  @doc """
  Creates a project.
  """
  @spec create_project(map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates a project.
  """
  @spec update_project(Project.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a project.
  """
  @spec delete_project(Project.t()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def delete_project(%Project{} = project) do
    repo().delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.
  """
  @spec change_project(Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  defp repo, do: Aludel.Repo.get()
end
