defmodule Mix.Tasks.Aludel.Install do
  @moduledoc """
  Installs Aludel by copying migrations to the host application.

  ## Usage

      $ mix aludel.install

  This task will:
  1. Copy all Aludel migrations to your app's priv/repo/migrations/ directory
  2. Add timestamp prefixes to prevent conflicts
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

    base_timestamp = timestamp()

    aludel_migrations_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.sort()
    |> Enum.with_index()
    |> Enum.each(fn {filename, index} ->
      copy_migration(filename, aludel_migrations_dir, app_migrations_dir, base_timestamp, index)
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

  defp copy_migration(filename, source_dir, dest_dir, base_timestamp, index) do
    # Extract the original migration name (everything after the timestamp)
    migration_name =
      filename
      |> String.split("_", parts: 2)
      |> List.last()

    # Check if a migration with this name already exists (with any timestamp)
    existing_migration =
      dest_dir
      |> File.ls!()
      |> Enum.find(fn f -> String.ends_with?(f, migration_name) end)

    if existing_migration do
      Mix.shell().info("* skipping #{migration_name} (already exists as #{existing_migration})")
    else
      # Generate monotonically increasing timestamp: base + index seconds
      migration_timestamp = add_seconds_to_timestamp(base_timestamp, index)
      new_filename = "#{migration_timestamp}_#{migration_name}"

      source = Path.join(source_dir, filename)
      dest = Path.join(dest_dir, new_filename)

      File.cp!(source, dest)
      Mix.shell().info("* copying #{new_filename}")
    end
  end

  defp add_seconds_to_timestamp(timestamp, seconds) do
    # Parse timestamp string to datetime
    <<year::binary-4, month::binary-2, day::binary-2, hour::binary-2, minute::binary-2,
      second::binary-2>> = timestamp

    base_datetime =
      NaiveDateTime.new!(
        String.to_integer(year),
        String.to_integer(month),
        String.to_integer(day),
        String.to_integer(hour),
        String.to_integer(minute),
        String.to_integer(second)
      )

    # Add seconds
    new_datetime = NaiveDateTime.add(base_datetime, seconds, :second)

    # Format back to timestamp string
    year = new_datetime.year |> Integer.to_string() |> String.pad_leading(4, "0")
    month = new_datetime.month |> Integer.to_string() |> String.pad_leading(2, "0")
    day = new_datetime.day |> Integer.to_string() |> String.pad_leading(2, "0")
    hour = new_datetime.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = new_datetime.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    second = new_datetime.second |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{year}#{month}#{day}#{hour}#{minute}#{second}"
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: "0#{i}"
  defp pad(i), do: "#{i}"
end
