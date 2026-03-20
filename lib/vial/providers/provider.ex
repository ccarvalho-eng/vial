defmodule Vial.Providers.Provider do
  @moduledoc """
  Schema for AI provider configurations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(name provider model)a
  @optional_fields ~w(config)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "providers" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:openai, :anthropic, :ollama]
    field :model, :string
    field :config, :map

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a provider.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
