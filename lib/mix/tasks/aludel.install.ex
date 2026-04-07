defmodule Mix.Tasks.Aludel.Install do
  @moduledoc """
  Installs Aludel by copying migrations to the host application.

  ## Usage

      $ mix aludel.install

  This task will:
  1. Copy all Aludel migrations to your app's priv/repo/migrations/ directory
  2. Preserve the original migration filenames so database versions stay stable across builds
  3. Show you what was copied

  ## Example

      $ mix aludel.install
      * copying priv/repo/migrations/20240101000001_create_prompts.exs
      * copying priv/repo/migrations/20240101000002_create_runs.exs
      ...

  After running this task, run `mix ecto.migrate` to apply the migrations.
  """

  @shortdoc "Installs Aludel migrations into the host application"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    aludel_migrations_dir = Application.app_dir(:aludel, ["priv", "repo", "migrations"])
    app_migrations_dir = Path.join(["priv", "repo", "migrations"])

    unless File.dir?(aludel_migrations_dir) do
      Mix.raise("Could not find Aludel migrations directory at #{aludel_migrations_dir}")
    end

    unless File.dir?(app_migrations_dir) do
      Mix.raise("""
      Could not find migrations directory at #{app_migrations_dir}.
      Please ensure your application has an Ecto repository set up.
      """)
    end

    aludel_migrations_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.sort()
    |> Enum.each(fn filename ->
      copy_migration(filename, aludel_migrations_dir, app_migrations_dir)
    end)

    Mix.shell().info("""

    Aludel migrations have been installed!

    Next steps:
      1. Run `mix ecto.migrate` to apply the migrations
      2. Configure Aludel in your config/config.exs:

          config :aludel, repo: YourApp.Repo

      3. Mount the dashboard in your router:

          import Aludel.Web.Router

          scope "/" do
            pipe_through :browser
            aludel_dashboard "/aludel"
          end

      4. Start your server and visit http://localhost:4000/aludel
    """)
  end

  defp copy_migration(filename, source_dir, dest_dir) do
    migration_name =
      filename
      |> String.split("_", parts: 2)
      |> List.last()

    existing_migration =
      dest_dir
      |> File.ls!()
      |> Enum.find(fn f -> String.ends_with?(f, migration_name) end)

    if existing_migration do
      Mix.shell().info("* skipping #{migration_name} (already exists as #{existing_migration})")
    else
      source = Path.join(source_dir, filename)
      dest = Path.join(dest_dir, filename)

      File.cp!(source, dest)
      Mix.shell().info("* copying #{filename}")
    end
  end
end


