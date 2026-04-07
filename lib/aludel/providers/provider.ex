defmodule Aludel.Providers.Provider do
  @moduledoc """
  Schema for AI provider configurations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields ~w(name provider model)a
  @optional_fields ~w(config)a
  @virtual_fields ~w(model_selection model_custom)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "providers" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:openai, :anthropic, :ollama]
    field :model, :string
    field :config, :map
    field :model_selection, :string, virtual: true
    field :model_custom, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a provider.
  """
  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, @required_fields ++ @optional_fields ++ @virtual_fields)
    |> normalize_model()
    |> validate_required(@required_fields)
  end

  defp normalize_model(changeset) do
    selection = get_field(changeset, :model_selection)

    model =
      case selection do
        "custom" -> get_field(changeset, :model_custom)
        value when is_binary(value) and value != "" -> value
        _ -> get_field(changeset, :model)
      end

    if is_nil(model) or model == "" do
      changeset
    else
      put_change(changeset, :model, model)
    end
  end
end
