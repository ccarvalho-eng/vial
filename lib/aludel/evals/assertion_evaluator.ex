defmodule Aludel.Evals.AssertionEvaluator do
  @moduledoc false

  alias Aludel.Evals.DeepCompare

  @default_threshold 100.0

  @spec evaluate(String.t(), map()) :: map()
  def evaluate(output, %{"type" => "contains", "value" => value} = assertion) do
    boolean_result(assertion, String.contains?(output, value))
  end

  def evaluate(output, %{"type" => "not_contains", "value" => value} = assertion) do
    boolean_result(assertion, not String.contains?(output, value))
  end

  def evaluate(output, %{"type" => "regex", "value" => pattern} = assertion) do
    passed =
      case Regex.compile(pattern) do
        {:ok, regex} -> Regex.match?(regex, output)
        {:error, _reason} -> false
      end

    boolean_result(assertion, passed)
  end

  def evaluate(output, %{"type" => "exact_match", "value" => value} = assertion) do
    boolean_result(assertion, output == value)
  end

  def evaluate(output, %{"type" => "json_field", "field" => field, "expected" => expected}) do
    case decode_json_output(output) do
      {:ok, json} ->
        actual_value = get_in(json, String.split(field, "."))
        passed = compare_json_values(actual_value, expected)

        %{
          "type" => "json_field",
          "passed" => passed,
          "score" => score_from_boolean(passed),
          "value" => %{"field" => field, "expected" => expected},
          "actual_value" => actual_value
        }

      {:error, _reason} ->
        %{
          "type" => "json_field",
          "passed" => false,
          "score" => 0.0,
          "value" => %{"field" => field, "expected" => expected},
          "actual_value" => nil
        }
    end
  end

  def evaluate(output, %{"type" => "json_deep_compare", "expected" => expected} = assertion) do
    threshold = normalize_threshold(assertion)

    case decode_json_output(output) do
      {:ok, json} ->
        score_details = DeepCompare.compare(json, expected)
        score = DeepCompare.score(score_details)
        passed = score >= threshold

        %{
          "type" => "json_deep_compare",
          "passed" => passed,
          "score" => score,
          "value" => %{"expected" => expected, "threshold" => threshold},
          "score_details" => score_details
        }

      {:error, _reason} ->
        %{
          "type" => "json_deep_compare",
          "passed" => false,
          "score" => 0.0,
          "value" => %{"expected" => expected, "threshold" => threshold},
          "score_details" => %{
            "matches" => 0,
            "total" => 0,
            "field_scores" => %{},
            "comparisons" => %{}
          }
        }
    end
  end

  def evaluate(_output, assertion) do
    %{
      "type" => Map.get(assertion, "type"),
      "passed" => false,
      "score" => 0.0,
      "value" => Map.get(assertion, "value")
    }
  end

  @spec score_for_results([map()]) :: float() | nil
  def score_for_results([]), do: nil

  def score_for_results(results) do
    scores =
      results
      |> Enum.map(&Map.get(&1, "score"))
      |> Enum.filter(&is_number/1)

    if scores == [] do
      nil
    else
      Float.round(Enum.sum(scores) / length(scores), 1)
    end
  end

  defp boolean_result(assertion, passed) do
    %{
      "type" => assertion["type"],
      "passed" => passed,
      "score" => score_from_boolean(passed),
      "value" => assertion["value"]
    }
  end

  defp score_from_boolean(true), do: 100.0
  defp score_from_boolean(false), do: 0.0

  defp normalize_threshold(%{"threshold" => threshold}) when is_integer(threshold),
    do: threshold / 1

  defp normalize_threshold(%{"threshold" => threshold}) when is_float(threshold), do: threshold
  defp normalize_threshold(_assertion), do: @default_threshold

  defp decode_json_output(output) do
    output
    |> String.trim()
    |> String.replace(~r/^```json\s*/i, "")
    |> String.replace(~r/^```\s*/, "")
    |> String.replace(~r/```\s*$/, "")
    |> String.trim()
    |> Jason.decode()
  end

  defp compare_json_values(actual, expected) when is_map(actual) or is_list(actual) do
    Jason.encode!(actual) == Jason.encode!(expected)
  end

  defp compare_json_values(actual, expected), do: actual == expected
end
