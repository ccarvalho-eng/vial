defmodule Aludel.Evals.TestCaseEditor do
  @moduledoc """
  Coordinates suite test case editing workflows outside the web layer.
  """

  alias Aludel.Evals
  alias Aludel.Evals.AssertionParser
  alias Aludel.Evals.TestCase

  @default_assertions [%{"type" => "contains", "value" => ""}]

  @spec create_test_case(binary(), map()) ::
          {:ok, TestCase.t()} | {:error, Ecto.Changeset.t()}
  def create_test_case(suite_id, prompt) do
    variable_values =
      prompt
      |> prompt_template()
      |> extract_variables()
      |> Map.new(fn variable -> {variable, ""} end)

    Evals.create_test_case(%{
      suite_id: suite_id,
      variable_values: variable_values,
      assertions: @default_assertions
    })
  end

  @spec build_form_params(TestCase.t()) :: map()
  def build_form_params(%TestCase{} = test_case) do
    %{
      "id" => test_case.id,
      "variable_values" => test_case.variable_values || %{}
    }
    |> Map.merge(AssertionParser.build_form_params(test_case.assertions || []))
  end

  @spec update_test_case(TestCase.t(), map(), AssertionParser.parse_mode()) ::
          {:ok, TestCase.t()} | {:error, String.t()} | {:error, Ecto.Changeset.t()}
  def update_test_case(%TestCase{} = test_case, params, edit_mode) do
    variables = Map.get(params, "variable_values", %{})

    with {:ok, assertions} <- AssertionParser.parse(edit_mode, params) do
      Evals.update_test_case(test_case, %{variable_values: variables, assertions: assertions})
    end
  end

  defp prompt_template(%{versions: [%{template: template} | _]}), do: template
  defp prompt_template(_prompt), do: ""

  defp extract_variables(template) do
    ~r/\{\{([^}]+)\}\}/
    |> Regex.scan(template)
    |> Enum.map(fn [_, variable] -> String.trim(variable) end)
    |> Enum.uniq()
  end
end
