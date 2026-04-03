defmodule Aludel.Projects.Project do
  @moduledoc """
  Schema for organizing prompts and test suites into projects.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aludel.Evals.Suite
  alias Aludel.Prompts.Prompt
  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(name)a
  @optional_fields ~w()a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field(:name, :string)

    has_many(:prompts, Prompt)
    has_many(:suites, Suite)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a project.
  """
  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> update_change(:name, &String.trim/1)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
  end
end
