defmodule Vial.Prompts.PromptVersion do
  @moduledoc """
  Schema for prompt versions.

  Versions are immutable snapshots of prompt templates with
  auto-incrementing version numbers and extracted variable names.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(prompt_id template)a
  @optional_fields ~w(version variables)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prompt_versions" do
    field :version, :integer
    field :template, :string
    field :variables, {:array, :string}, default: []

    belongs_to :prompt, Vial.Prompts.Prompt

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a prompt version.

  Validates that prompt_id and template are present.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(prompt_version, attrs) do
    prompt_version
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
