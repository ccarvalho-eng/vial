defmodule Aludel.Evals.AssertionParser do
  @moduledoc """
  Parses and validates assertion payloads from suite editor forms.
  """

  @valid_types ["contains", "not_contains", "regex", "exact_match", "json_field"]

  @type parse_mode :: :json | :visual

  @spec parse(parse_mode(), map()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(:json, params) do
    case Jason.decode(params["assertions_json"] || "[]") do
      {:ok, assertions} when is_list(assertions) ->
        validate(assertions)

      {:ok, _value} ->
        {:error, "Invalid JSON: assertions must be a list"}

      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON syntax in assertions"}
    end
  end

  def parse(:visual, params) do
    params
    |> Map.get("assertions", %{})
    |> normalize_assertion_params()
    |> parse_visual_assertions()
    |> case do
      {:ok, assertions} -> validate(assertions)
      {:error, _message} = error -> error
    end
  end

  @spec validate([map()]) :: {:ok, [map()]} | {:error, String.t()}
  def validate(assertions) when is_list(assertions) do
    assertions
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, assertions}, fn {assertion, idx}, _acc ->
      type = Map.get(assertion, "type")

      cond do
        type not in @valid_types ->
          {:halt,
           {:error,
            "Invalid assertion type at index #{idx}: #{inspect(type)}. Must be one of: #{Enum.join(@valid_types, ", ")}"}}

        type == "json_field" and
            (not Map.has_key?(assertion, "field") or not Map.has_key?(assertion, "expected")) ->
          {:halt,
           {:error,
            "Assertion at index #{idx}: json_field type requires 'field' and 'expected' fields"}}

        type != "json_field" and not Map.has_key?(assertion, "value") ->
          {:halt, {:error, "Assertion at index #{idx}: #{type} type requires 'value' field"}}

        true ->
          {:cont, {:ok, assertions}}
      end
    end)
  end

  @spec build_form_params([map()]) :: map()
  def build_form_params(assertions) do
    %{
      "assertions_json" => Jason.encode!(assertions, pretty: true),
      "assertions" => build_assertion_params(assertions)
    }
  end

  defp parse_visual_assertions(assertion_params) do
    with {:ok, assertion_indices} <- parse_assertion_indices(assertion_params) do
      {:ok, Enum.map(assertion_indices, &build_visual_assertion(assertion_params, &1))}
    end
  end

  defp build_assertion_params(assertions) do
    assertions
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {assertion, idx}, acc ->
      acc
      |> Map.put("assertion_type_#{idx}", assertion["type"])
      |> maybe_put_assertion_value(idx, assertion)
    end)
  end

  defp maybe_put_assertion_value(params, idx, %{"type" => "json_field"} = assertion) do
    params
    |> Map.put("assertion_field_#{idx}", assertion["field"] || "")
    |> Map.put("assertion_expected_#{idx}", assertion["expected"] || "")
  end

  defp maybe_put_assertion_value(params, idx, assertion) do
    Map.put(params, "assertion_value_#{idx}", assertion["value"] || "")
  end

  defp build_visual_assertion(assertion_params, idx) do
    type = Map.get(assertion_params, "assertion_type_#{idx}")

    if type == "json_field" do
      %{
        "type" => type,
        "field" => Map.get(assertion_params, "assertion_field_#{idx}", ""),
        "expected" => Map.get(assertion_params, "assertion_expected_#{idx}", "")
      }
    else
      %{
        "type" => type,
        "value" => Map.get(assertion_params, "assertion_value_#{idx}", "")
      }
    end
  end

  defp parse_assertion_indices(assertion_params) do
    assertion_params
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, "assertion_type_"))
    |> Enum.reduce_while({:ok, []}, fn "assertion_type_" <> idx, {:ok, indices} ->
      case Integer.parse(idx) do
        {parsed_idx, ""} ->
          {:cont, {:ok, [parsed_idx | indices]}}

        _ ->
          {:halt, {:error, "Invalid assertion index: #{idx}"}}
      end
    end)
    |> case do
      {:ok, indices} -> {:ok, Enum.sort(indices)}
      {:error, _message} = error -> error
    end
  end

  defp normalize_assertion_params(params) when is_map(params), do: params
  defp normalize_assertion_params(params) when is_list(params), do: Map.new(params)
  defp normalize_assertion_params(_params), do: %{}
end
