defmodule Mix.Tasks.Aludel.Seed do
  @moduledoc """
  Runs Aludel seed data.

  ## Usage

      mix aludel.seed

  This task will populate your database with sample Aludel data including:
  - Default providers (Ollama, OpenAI)
  - Sample prompts for testing
  - Evaluation suites with test cases
  - Demo evolution data across multiple versions
  """

  use Mix.Task

  @shortdoc "Runs Aludel seed data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    seeds_path = Path.join(:code.priv_dir(:aludel), "repo/seeds.exs")

    if File.exists?(seeds_path) do
      Code.eval_file(seeds_path)
    else
      Mix.shell().error("Seeds file not found at #{seeds_path}")
    end
  end
end
