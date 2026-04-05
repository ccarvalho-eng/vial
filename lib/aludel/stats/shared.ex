defmodule Aludel.Stats.Shared do
  @moduledoc false

  def to_integer(nil), do: 0
  def to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  def to_integer(value) when is_integer(value), do: value

  def to_float(nil), do: 0.0
  def to_float(%Decimal{} = value), do: Decimal.to_float(value)
  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_integer(value), do: value / 1

  def repo, do: Aludel.Repo.get()
end
