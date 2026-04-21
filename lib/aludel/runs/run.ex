defmodule Aludel.Runs.Run do
  @moduledoc """
  Schema for managing runs.

  A run represents an execution of a prompt version with specific
  variable values across multiple providers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aludel.Prompts.PromptVersion
  alias Aludel.Runs.RunResult
  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(prompt_version_id variable_values)a
  @optional_fields ~w(name provider_ids)a
  @execution_fields ~w(status started_at completed_at error_summary)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "runs" do
    field :name, :string
    field :variable_values, :map
    field :provider_ids, {:array, :string}, virtual: true, default: []

    field :status, Ecto.Enum,
      values: [:pending, :running, :completed, :partial_failure, :failed],
      default: :pending

    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_summary, :string

    belongs_to(:prompt_version, PromptVersion)
    has_many(:run_results, RunResult)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a run.

  Validates that prompt_version_id and variable_values are present.
  """
  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Changeset for executor-owned lifecycle transitions.
  """
  @spec execution_changeset(t(), map()) :: Changeset.t()
  def execution_changeset(run, attrs) do
    run
    |> cast(attrs, @execution_fields)
  end
end
