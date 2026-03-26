defmodule Mix.Tasks.Vial.Seed do
  @moduledoc """
  Runs Vial seed data.

  ## Usage

      mix vial.seed

  This task will populate your database with sample Vial data including:
  - Default providers (Ollama, OpenAI)
  - Sample prompts for testing
  - Evaluation suites with test cases
  - Demo evolution data across multiple versions
  """

  use Mix.Task

  @shortdoc "Runs Vial seed data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    seeds_path = Path.join(:code.priv_dir(:vial), "repo/seeds.exs")

    if File.exists?(seeds_path) do
      Code.eval_file(seeds_path)
    else
      Mix.shell().error("Seeds file not found at #{seeds_path}")
    end
  end
end
