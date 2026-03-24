defmodule Vial.PromptsFixtures do
  @moduledoc """
  Test fixtures for creating prompts.
  """

  def prompt_fixture(attrs \\ %{}) do
    {:ok, prompt} =
      attrs
      |> Enum.into(%{
        name: "Sample Prompt",
        description: "A sample prompt",
        tags: ["sample"]
      })
      |> then(&Vial.Prompts.create_prompt(Vial.Repo, &1))

    prompt
  end
end
