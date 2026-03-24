defmodule Mix.Tasks.Vial.Install do
  @moduledoc """
  Generates a migration file for Vial database tables.

  ## Usage

      mix vial.install

  This will create a migration file in your project's priv/repo/migrations/
  directory with all the necessary tables for Vial.

  ## Options

    * `--prefix` - Database schema prefix (default: "public")

  ## Examples

      # Generate migration with default "public" schema
      mix vial.install

      # Generate migration with custom schema
      mix vial.install --prefix my_schema

  """

  use Mix.Task

  @shortdoc "Generates Vial database migration"

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [prefix: :string])
    prefix = Keyword.get(opts, :prefix, "public")

    # Ensure we're in a Mix project
    Mix.Project.get!()

    # Get the repo module from config
    repo = get_repo()
    repo_name = repo |> Module.split() |> List.last()

    # Generate timestamp
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    filename = "#{timestamp}_add_vial_tables.exs"
    migrations_dir = Path.join(["priv", "repo", "migrations"])
    File.mkdir_p!(migrations_dir)
    path = Path.join(migrations_dir, filename)

    # Generate migration content
    content = migration_template(repo, repo_name, prefix)

    # Write the file
    File.write!(path, content)

    Mix.shell().info("""

    Generated Vial migration: #{path}

    Run the migration with:

        mix ecto.migrate

    """)
  end

  defp get_repo do
    app = Mix.Project.config()[:app]

    case Application.get_env(app, :ecto_repos) do
      [repo | _] ->
        repo

      _ ->
        Mix.raise("""
        Could not find Ecto repo in your application configuration.

        Please ensure you have an Ecto repo configured in config/config.exs:

            config :my_app, ecto_repos: [MyApp.Repo]
        """)
    end
  end

  defp migration_template(_repo, repo_name, prefix) do
    module_name = "#{repo_name}.Migrations.AddVialTables"

    prefix_option =
      if prefix == "public" do
        ""
      else
        ", prefix: \"#{prefix}\""
      end

    """
    defmodule #{module_name} do
      use Ecto.Migration

      def up do
        Vial.Migrations.up(#{String.trim_leading(prefix_option, ", ")})
      end

      def down do
        Vial.Migrations.down(#{String.trim_leading(prefix_option, ", ")})
      end
    end
    """
  end
end
