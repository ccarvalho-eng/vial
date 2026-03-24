defmodule Vial.Prompts.Prompt do
  @moduledoc """
  Schema for managing prompts.

  A prompt is a template container that can have multiple versions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(name)a
  @optional_fields ~w(description tags)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vial_prompts" do
    field :name, :string
    field :description, :string
    field :tags, {:array, :string}, default: []

    has_many :versions, Vial.Prompts.PromptVersion

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a prompt.

  Validates that name is present.
  Converts comma-separated tags string to array if needed.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(prompt, attrs) do
    attrs = normalize_tags(attrs)

    prompt
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  defp normalize_tags(attrs) when is_map(attrs) do
    case Map.get(attrs, "tags") do
      tags when is_binary(tags) ->
        parsed_tags =
          tags
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        Map.put(attrs, "tags", parsed_tags)

      _ ->
        attrs
    end
  end

  defp normalize_tags(attrs), do: attrs
end
