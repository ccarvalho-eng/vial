defmodule Mix.Tasks.Vial.Install do
  @moduledoc """
  Installs Vial by copying migrations to the host application.

  ## Usage

      $ mix vial.install

  This task will:
  1. Copy all Vial migrations to your app's priv/repo/migrations/ directory
  2. Add timestamp prefixes to prevent conflicts
  3. Show you what was copied

  ## Example

      $ mix vial.install
      * copying priv/repo/migrations/20240101000001_create_prompts.exs
      * copying priv/repo/migrations/20240101000002_create_runs.exs
      ...

  After running this task, run `mix ecto.migrate` to apply the migrations.
  """

  @shortdoc "Installs Vial migrations into the host application"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    vial_migrations_dir = Application.app_dir(:vial, ["priv", "repo", "migrations"])
    app_migrations_dir = Path.join(["priv", "repo", "migrations"])

    unless File.dir?(vial_migrations_dir) do
      Mix.raise("Could not find Vial migrations directory at #{vial_migrations_dir}")
    end

    unless File.dir?(app_migrations_dir) do
      Mix.raise("""
      Could not find migrations directory at #{app_migrations_dir}.
      Please ensure your application has an Ecto repository set up.
      """)
    end

    vial_migrations_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.each(&copy_migration(&1, vial_migrations_dir, app_migrations_dir))

    Mix.shell().info("""

    Vial migrations have been installed!

    Next steps:
      1. Run `mix ecto.migrate` to apply the migrations
      2. Configure Vial in your config/config.exs:

          config :vial, repo: YourApp.Repo

      3. Mount the dashboard in your router:

          import Vial.Web.Router

          scope "/" do
            pipe_through :browser
            vial_dashboard "/vial"
          end

      4. Start your server and visit http://localhost:4000/vial
    """)
  end

  defp copy_migration(filename, source_dir, dest_dir) do
    # Extract the original migration name (everything after the timestamp)
    migration_name =
      filename
      |> String.split("_", parts: 2)
      |> List.last()

    # Generate a new timestamp for the host app
    timestamp = timestamp()
    new_filename = "#{timestamp}_#{migration_name}"

    source = Path.join(source_dir, filename)
    dest = Path.join(dest_dir, new_filename)

    if File.exists?(dest) do
      Mix.shell().info("* skipping #{new_filename} (already exists)")
    else
      File.cp!(source, dest)
      Mix.shell().info("* copying #{new_filename}")
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: "0#{i}"
  defp pad(i), do: "#{i}"
end
