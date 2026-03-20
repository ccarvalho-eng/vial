defmodule Vial.EvalsFixtures do
  @moduledoc """
  Test fixtures for creating evaluation suites and test cases.
  """

  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures

  def suite_fixture(attrs \\ %{}) do
    prompt = prompt_fixture()

    {:ok, suite} =
      attrs
      |> Enum.into(%{
        name: "Sample Suite",
        prompt_id: prompt.id
      })
      |> Vial.Evals.create_suite()

    suite
  end

  def test_case_fixture(attrs \\ %{}) do
    suite = if Map.has_key?(attrs, :suite_id), do: nil, else: suite_fixture()

    {:ok, test_case} =
      attrs
      |> Enum.into(%{
        suite_id: suite && suite.id,
        variable_values: %{"name" => "John"},
        assertions: [%{"type" => "contains", "value" => "Hello"}]
      })
      |> Vial.Evals.create_test_case()

    test_case
  end

  def suite_run_fixture(attrs \\ %{}) do
    suite = if Map.has_key?(attrs, :suite_id), do: nil, else: suite_fixture()
    prompt = prompt_fixture()
    {:ok, version} = Vial.Prompts.create_prompt_version(prompt, "Template {{var}}")
    provider = provider_fixture()

    {:ok, suite_run} =
      attrs
      |> Enum.into(%{
        suite_id: suite && suite.id,
        prompt_version_id: version.id,
        provider_id: provider.id,
        results: [],
        passed: 0,
        failed: 0
      })
      |> Vial.Evals.create_suite_run()

    suite_run
  end
end
