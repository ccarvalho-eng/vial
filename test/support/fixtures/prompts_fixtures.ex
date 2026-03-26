defmodule Aludel.PromptsFixtures do
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
      |> Aludel.Prompts.create_prompt()

    prompt
  end
end
