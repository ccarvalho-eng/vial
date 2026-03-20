defmodule Vial.Runs.Run do
  @moduledoc """
  Schema for managing runs.

  A run represents an execution of a prompt version with specific
  variable values across multiple providers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(prompt_version_id variable_values)a
  @optional_fields ~w(name)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "runs" do
    field :name, :string
    field :variable_values, :map

    belongs_to :prompt_version, Vial.Prompts.PromptVersion
    has_many :run_results, Vial.Runs.RunResult

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a run.

  Validates that prompt_version_id and variable_values are present.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
