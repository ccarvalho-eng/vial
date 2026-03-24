defmodule Vial.ProvidersFixtures do
  @moduledoc """
  Test fixtures for creating providers.
  """

  def provider_fixture(attrs \\ %{}) do
    {:ok, provider} =
      attrs
      |> Enum.into(%{
        name: "OpenAI GPT-4o",
        provider: :openai,
        model: "gpt-4o",
        config: %{"temperature" => 0.7, "max_tokens" => 1000}
      })
      |> then(&Vial.Providers.create_provider(Vial.Repo, &1))

    provider
  end
end
