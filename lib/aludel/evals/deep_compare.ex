defmodule Aludel.Evals.DeepCompare do
  @moduledoc false

  @type comparison :: map()

  @spec compare(term(), term()) :: comparison()
  def compare(actual, expected) do
    {matches, total, field_scores, comparisons} = do_compare(actual, expected, nil)

    %{
      "matches" => matches,
      "total" => total,
      "field_scores" => field_scores,
      "comparisons" => comparisons
    }
  end

  @spec score(comparison()) :: float()
  def score(%{"total" => 0}), do: 0.0

  def score(%{"matches" => matches, "total" => total}) do
    Float.round(matches / total * 100, 1)
  end

  defp do_compare(actual, expected, path) when is_map(expected) do
    if map_size(expected) == 0 do
      leaf_result(path, actual == expected, expected, actual)
    else
      expected
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.reduce({0, 0, %{}, %{}}, fn {key, expected_value}, acc ->
        actual_value = map_value(actual, key)
        merge_results(acc, do_compare(actual_value, expected_value, join_path(path, key)))
      end)
    end
  end

  defp do_compare(actual, expected, path) when is_list(expected) do
    if expected == [] do
      leaf_result(path, actual == expected, expected, actual)
    else
      compare_list(actual, expected, path, 0, {0, 0, %{}, %{}})
    end
  end

  defp do_compare(actual, expected, path) do
    leaf_result(path, actual == expected, expected, actual)
  end

  defp compare_list(actual, [expected_head | expected_tail], path, index, acc)
       when is_list(actual) do
    case actual do
      [actual_head | actual_tail] ->
        merged =
          merge_results(acc, do_compare(actual_head, expected_head, join_index(path, index)))

        compare_list(actual_tail, expected_tail, path, index + 1, merged)

      [] ->
        merged =
          merge_results(acc, do_compare(nil, expected_head, join_index(path, index)))

        compare_list([], expected_tail, path, index + 1, merged)
    end
  end

  defp compare_list(_actual, [expected_head | expected_tail], path, index, acc) do
    merged = merge_results(acc, do_compare(nil, expected_head, join_index(path, index)))
    compare_list(nil, expected_tail, path, index + 1, merged)
  end

  defp compare_list(_actual, [], _path, _index, acc), do: acc

  defp leaf_result(path, passed, expected, actual) do
    path = path || "$"

    {
      if(passed, do: 1, else: 0),
      1,
      %{path => if(passed, do: 1, else: 0)},
      %{path => %{"passed" => passed, "expected" => expected, "actual" => actual}}
    }
  end

  defp merge_results(
         {matches, total, field_scores, comparisons},
         {more_matches, more_total, more_field_scores, more_comparisons}
       ) do
    {
      matches + more_matches,
      total + more_total,
      Map.merge(field_scores, more_field_scores),
      Map.merge(comparisons, more_comparisons)
    }
  end

  defp join_path(nil, key), do: to_string(key)
  defp join_path(path, key), do: "#{path}.#{key}"

  defp join_index(nil, index), do: "[#{index}]"
  defp join_index(path, index), do: "#{path}[#{index}]"

  defp map_value(actual, key) when is_map(actual), do: Map.get(actual, key)
  defp map_value(_actual, _key), do: nil
end
