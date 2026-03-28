defmodule Aludel.Evals.TestCase do
  @moduledoc """
  Schema for individual test cases within a suite.

  Test cases define variable values to substitute into prompts
  and assertions to validate the LLM output.

  Supported assertion types:
  - contains: Check if output contains a specific string
  - not_contains: Check if output does not contain a string
  - regex: Match output against a regular expression
  - exact_match: Check for exact string match
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(suite_id variable_values assertions)a
  @optional_fields ~w()a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_cases" do
    field :variable_values, :map
    field :assertions, {:array, :map}

    belongs_to :suite, Aludel.Evals.Suite
    has_many :documents, Aludel.Evals.TestCaseDocument, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a test case.

  Validates that suite_id, variable_values, and assertions are
  present.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(test_case, attrs) do
    test_case
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
