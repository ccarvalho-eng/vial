defmodule Aludel.Prompts.Project do
  @moduledoc """
  Schema for organizing prompts into projects.

  Projects can be nested to create hierarchical organization.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(name)a
  @optional_fields ~w(parent_id position)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :name, :string
    field :position, :integer, default: 0

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :prompts, Aludel.Prompts.Prompt

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a project.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
