defmodule Aludel.Evals.TestCaseDocument do
  @moduledoc """
  Schema for file attachments associated with test cases.

  Documents can be used to provide additional context or data for
  test cases, such as input files, reference documents, or
  expected outputs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aludel.Evals.TestCase
  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  @max_size_bytes 10 * 1024 * 1024

  @supported_types ~w(
    image/png
    image/jpeg
    image/jpg
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    text/csv
    application/json
    text/plain
  )

  @required_fields ~w(
    test_case_id
    filename
    content_type
    data
    size_bytes
  )a
  @optional_fields ~w()a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_case_documents" do
    field :filename, :string
    field :content_type, :string
    field :data, :binary
    field :size_bytes, :integer

    belongs_to(:test_case, TestCase)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns maximum allowed file size in bytes.
  """
  @spec max_size_bytes() :: non_neg_integer()
  def max_size_bytes, do: @max_size_bytes

  @doc """
  Returns list of supported MIME types.
  """
  @spec supported_types() :: [String.t()]
  def supported_types, do: @supported_types

  @doc """
  Changeset for creating or updating a test case document.

  Validates that all required fields are present.
  """
  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(test_case_document, attrs) do
    test_case_document
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:content_type, @supported_types,
      message: "is not a supported document type"
    )
    |> validate_number(:size_bytes,
      less_than_or_equal_to: @max_size_bytes,
      message: "file size must be less than 10MB"
    )
    |> validate_length(:filename, max: 255)
    |> validate_length(:content_type, max: 100)
    |> foreign_key_constraint(:test_case_id)
  end
end
