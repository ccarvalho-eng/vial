defmodule Aludel.Stats.Shared do
  @moduledoc false

  def to_integer(nil), do: 0
  def to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  def to_integer(value) when is_integer(value), do: value

  def to_float(nil), do: 0.0
  def to_float(%Decimal{} = value), do: Decimal.to_float(value)
  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_integer(value), do: value / 1

  def suite_run_total_cost(%{results: results}) when is_list(results) do
    Enum.reduce(results, 0.0, fn result, acc ->
      acc + cost_value(Map.get(result, "cost_usd"))
    end)
  end

  def suite_run_total_cost(_), do: 0.0

  def suite_run_cost_entries(%{results: results}) when is_list(results) do
    Enum.count(results, &(not is_nil(Map.get(&1, "cost_usd"))))
  end

  def suite_run_cost_entries(_), do: 0

  defp cost_value(nil), do: 0.0
  defp cost_value(value) when is_integer(value), do: value / 1
  defp cost_value(value) when is_float(value), do: value
  defp cost_value(%Decimal{} = value), do: Decimal.to_float(value)

  def repo, do: Aludel.Repo.get()
end
