defmodule Vial.Runs.RunResult do
  @moduledoc """
  Schema for run results.

  A run result captures the output and metrics from executing a run
  against a specific provider.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(run_id provider_id status)a
  @optional_fields ~w(output input_tokens output_tokens latency_ms cost_usd error)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vial_run_results" do
    field :output, :string
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :latency_ms, :integer
    field :cost_usd, :float
    field :status, Ecto.Enum, values: [:pending, :streaming, :completed, :error]
    field :error, :string

    belongs_to :run, Vial.Runs.Run
    belongs_to :provider, Vial.Providers.Provider

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a run result.

  Validates that run_id, provider_id, and status are present.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run_result, attrs) do
    run_result
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:run_id)
    |> foreign_key_constraint(:provider_id)
  end
end
