defmodule Vial.RunsFixtures do
  @moduledoc """
  Test fixtures for creating runs and run results.
  """

  import Vial.PromptsFixtures
  import Vial.ProvidersFixtures

  @doc """
  Creates a run fixture.

  Requires a prompt version. Creates one if not provided.
  """
  def run_fixture(attrs \\ %{}) do
    prompt_version =
      if Map.has_key?(attrs, :prompt_version_id) do
        nil
      else
        prompt = prompt_fixture()
        {:ok, version} = Vial.Prompts.create_prompt_version(Vial.Repo, prompt, "Hello {{user}}")
        version
      end

    base_attrs = %{
      name: "Test Run",
      variable_values: %{"user" => "Alice"}
    }

    base_attrs =
      if prompt_version do
        Map.put(base_attrs, :prompt_version_id, prompt_version.id)
      else
        base_attrs
      end

    {:ok, run} =
      attrs
      |> Enum.into(base_attrs)
      |> then(&Vial.Runs.create_run(Vial.Repo, &1))

    run
  end

  @doc """
  Creates a run result fixture.

  Requires a run and provider. Creates them if not provided.
  """
  def run_result_fixture(attrs \\ %{}) do
    run =
      if Map.has_key?(attrs, :run_id) do
        nil
      else
        run_fixture()
      end

    provider =
      if Map.has_key?(attrs, :provider_id) do
        nil
      else
        provider_fixture()
      end

    base_attrs = %{
      output: "Test output",
      input_tokens: 10,
      output_tokens: 5,
      latency_ms: 500,
      cost_usd: 0.001,
      status: :completed
    }

    base_attrs =
      base_attrs
      |> then(fn attrs ->
        if run, do: Map.put(attrs, :run_id, run.id), else: attrs
      end)
      |> then(fn attrs ->
        if provider, do: Map.put(attrs, :provider_id, provider.id), else: attrs
      end)

    {:ok, run_result} =
      attrs
      |> Enum.into(base_attrs)
      |> then(&Vial.Runs.create_run_result(Vial.Repo, &1))

    run_result
  end
end
