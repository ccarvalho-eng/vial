defmodule Aludel.Prompts do
  @moduledoc """
  Context for managing prompts and their versions.
  """

  import Ecto.Query

  alias Aludel.Prompts.{Evolution, Prompt, PromptVersion}
  alias Ecto.Changeset

  @doc """
  Lists all prompts in the system.

  When called without params, returns all prompts as a list.
  When called with pagination params, returns a paginated result.

  ## Options

    * `:page` - Page number (default: 1)
    * `:page_size` - Number of items per page (default: 20)
    * `:project_id` - Filter by project ID

  """
  @spec list_prompts() :: [Prompt.t()]
  def list_prompts do
    repo().all(Prompt)
  end

  @spec list_prompts(map()) :: %{
          entries: [Prompt.t()],
          page_number: integer(),
          page_size: integer(),
          total_entries: integer(),
          total_pages: integer()
        }
  def list_prompts(params) when is_map(params) do
    page = Map.get(params, :page, 1)
    page_size = Map.get(params, :page_size, 20)
    project_id = Map.get(params, :project_id)

    query = from(p in Prompt, order_by: [desc: p.inserted_at])
    query = if project_id, do: where(query, [p], p.project_id == ^project_id), else: query

    total = repo().aggregate(query, :count)
    offset = (page - 1) * page_size

    entries =
      query
      |> limit(^page_size)
      |> offset(^offset)
      |> repo().all()

    %{
      entries: entries,
      page_number: page,
      page_size: page_size,
      total_entries: total,
      total_pages: ceil(total / page_size)
    }
  end

  @doc """
  Lists all prompts with their versions preloaded.

  Versions are ordered by version number descending.
  """
  @spec list_prompts_with_versions() :: [Prompt.t()]
  def list_prompts_with_versions do
    query =
      from p in Prompt,
        preload: [versions: ^from(v in PromptVersion, order_by: [desc: v.version])]

    repo().all(query)
  end

  @doc """
  Gets a prompt by ID, raising if not found.
  """
  @spec get_prompt!(binary()) :: Prompt.t()
  def get_prompt!(id) do
    repo().get!(Prompt, id)
  end

  @doc """
  Gets a prompt with all versions preloaded, ordered by version
  descending.
  """
  @spec get_prompt_with_versions!(binary()) :: Prompt.t()
  def get_prompt_with_versions!(id) do
    query =
      from p in Prompt,
        where: p.id == ^id,
        preload: [versions: ^from(v in PromptVersion, order_by: [desc: v.version])]

    repo().one!(query)
  end

  @doc """
  Gets a prompt version by ID, raising if not found.

  Preloads the associated prompt.
  """
  @spec get_prompt_version!(binary()) :: PromptVersion.t()
  def get_prompt_version!(id) do
    PromptVersion
    |> repo().get!(id)
    |> repo().preload(:prompt)
  end

  @doc """
  Returns a changeset for tracking prompt changes.
  """
  @spec change_prompt(Prompt.t(), map()) :: Ecto.Changeset.t()
  def change_prompt(%Prompt{} = prompt, attrs \\ %{}) do
    Prompt.changeset(prompt, attrs)
  end

  @doc """
  Creates a new prompt.
  """
  @spec create_prompt(map()) ::
          {:ok, Prompt.t()} | {:error, Changeset.t()}
  def create_prompt(attrs \\ %{}) do
    %Prompt{}
    |> Prompt.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing prompt.
  """
  @spec update_prompt(Prompt.t(), map()) ::
          {:ok, Prompt.t()} | {:error, Changeset.t()}
  def update_prompt(%Prompt{} = prompt, attrs) do
    prompt
    |> Prompt.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a prompt.
  """
  @spec delete_prompt(Prompt.t()) ::
          {:ok, Prompt.t()} | {:error, Changeset.t()}
  def delete_prompt(%Prompt{} = prompt) do
    repo().delete(prompt)
  end

  @doc """
  Creates a new version of a prompt.

  Auto-increments the version number and extracts variables from
  the template.
  """
  @spec create_prompt_version(Prompt.t(), String.t()) ::
          {:ok, PromptVersion.t()} | {:error, Changeset.t()}
  def create_prompt_version(%Prompt{} = prompt, template) do
    variables = extract_variables(template)
    version_number = get_next_version_number(prompt.id)

    %PromptVersion{}
    |> PromptVersion.changeset(%{
      prompt_id: prompt.id,
      version: version_number,
      template: template,
      variables: variables
    })
    |> repo().insert()
  end

  @doc """
  Extracts variable names from a template.

  Variables are identified by {{variable_name}} syntax.
  Returns unique variable names in order of first appearance.
  """
  @spec extract_variables(String.t()) :: [String.t()]
  def extract_variables(template) do
    ~r/\{\{(\w+)\}\}/
    |> Regex.scan(template, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Returns aggregated evolution metrics for all versions of a prompt.

  Includes pass rates, cost, latency, and per-provider breakdown.
  """
  @spec get_evolution_metrics(binary()) :: [map()]
  def get_evolution_metrics(prompt_id) do
    Evolution.get_metrics(prompt_id)
  end

  # Private functions

  defp get_next_version_number(prompt_id) do
    query =
      from v in PromptVersion,
        where: v.prompt_id == ^prompt_id,
        select: max(v.version)

    case repo().one(query) do
      nil -> 1
      max_version -> max_version + 1
    end
  end

  defp repo, do: Aludel.Repo.get()
end
