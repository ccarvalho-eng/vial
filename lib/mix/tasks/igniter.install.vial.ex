defmodule Mix.Tasks.Igniter.Install.Vial do
  @moduledoc """
  Installs Vial into a Phoenix application.

  ## Usage

      mix igniter.install vial

  ## Options

    * `--path` - The path to mount the dashboard at (default: "/dev/vial" in
      dev, "/admin/vial" in prod)
    * `--prefix` - Database schema prefix for multi-tenant apps (default:
      "public")
    * `--dev-only` - Only install in dev environment (default: false)

  ## Examples

      # Basic installation
      mix igniter.install vial

      # Install at custom path
      mix igniter.install vial --path /internal/prompts

      # Install with database prefix for multi-tenancy
      mix igniter.install vial --prefix tenant_schema

      # Dev-only installation
      mix igniter.install vial --dev-only

  ## What it does

  1. Adds Vial dependency to your mix.exs
  2. Adds TaskSupervisor to your application supervision tree
  3. Imports Vial.Router in your router
  4. Mounts vial_dashboard at the specified path
  5. Adds Vial.Static plug to your endpoint
  6. Generates the Vial database migration
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :igniter,
      # Dependencies that must be installed before this task can run
      adds_deps: [vial: "~> 0.1.0"],
      # An example invocation
      example: "mix igniter.install vial --path /admin/vial",
      # A list of environments that this should be installed in
      only: nil,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks that should be run before this one
      composes: [],
      # `OptionParser` schema
      schema: [
        path: :string,
        prefix: :string,
        dev_only: :boolean
      ],
      # Default values for options
      defaults: [
        prefix: "public",
        dev_only: false
      ],
      # CLI aliases
      aliases: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    options = igniter.args.options
    path = options[:path]
    prefix = options[:prefix]
    dev_only = options[:dev_only]

    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Project.Module.module_name(igniter, "#{app_name}_web")
    repo_module = find_repo_module(igniter, app_name)

    igniter
    |> add_task_supervisor(app_name)
    |> add_vial_static_plug(web_module)
    |> setup_router(web_module, repo_module, app_name, path, dev_only)
    |> generate_migration(prefix)
  end

  defp find_repo_module(igniter, app_name) do
    # Try to find the repo module
    repo_name = Igniter.Project.Module.module_name(igniter, "#{app_name}.Repo")

    if Igniter.Project.Module.module_exists(igniter, repo_name) do
      repo_name
    else
      nil
    end
  end

  defp add_task_supervisor(igniter, app_name) do
    supervisor_name =
      Igniter.Project.Module.module_name(igniter, "#{app_name}.TaskSupervisor")

    Igniter.Project.Application.add_new_child(
      igniter,
      {Task.Supervisor, name: supervisor_name},
      after: [:ecto_repos]
    )
  end

  defp add_vial_static_plug(igniter, web_module) do
    endpoint_module = Module.concat(web_module, "Endpoint")

    Igniter.Project.Module.find_and_update_module!(igniter, endpoint_module, fn
      zipper ->
        case Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :plug,
               2,
               fn call ->
                 Igniter.Code.Function.argument_matches_predicate?(
                   call,
                   0,
                   &match?({:__aliases__, _, [:Plug, :Static]}, &1)
                 )
               end
             ) do
          {:ok, zipper} ->
            # Insert Vial.Static before the app's Plug.Static
            Igniter.Code.Common.add_code(zipper, """
            # Serve Vial static assets
            plug Vial.Static
            """)

          :error ->
            # Couldn't find Plug.Static, add at the end of the module
            {:ok, zipper}
        end
    end)
  end

  defp setup_router(igniter, web_module, repo_module, app_name, path, dev_only) do
    router_module = Module.concat(web_module, "Router")

    task_supervisor =
      Igniter.Project.Module.module_name(igniter, "#{app_name}.TaskSupervisor")

    default_path =
      if dev_only do
        "/dev/vial"
      else
        "/admin/vial"
      end

    mount_path = path || default_path

    router_config = """
    vial_dashboard "#{mount_path}",
      repo: #{inspect(repo_module)},
      task_supervisor: #{inspect(task_supervisor)}
    """

    igniter
    |> Igniter.Project.Module.find_and_update_module!(router_module, fn zipper ->
      # Add import
      Igniter.Code.Common.add_code(zipper, "import Vial.Router", :before)
    end)
    |> then(fn igniter ->
      if dev_only do
        # Add to dev scope
        Igniter.Project.Module.find_and_update_module!(igniter, router_module, fn
          zipper ->
            case find_or_create_dev_scope(zipper) do
              {:ok, zipper} ->
                Igniter.Code.Common.add_code(zipper, router_config)

              :error ->
                {:ok, zipper}
            end
        end)
      else
        # Add to a new scope or existing admin scope
        Igniter.Project.Module.find_and_update_module!(igniter, router_module, fn
          zipper ->
            Igniter.Code.Common.add_code(zipper, """
            scope "/admin", #{inspect(web_module)} do
              pipe_through :browser

              #{router_config}
            end
            """)
        end)
      end
    end)
  end

  defp find_or_create_dev_scope(zipper) do
    # Try to find existing dev scope
    case Igniter.Code.Common.move_to(zipper, fn z ->
           match?(
             {:if, _,
              [
                {{:., _, [{:__aliases__, _, [:Mix]}, :env]}, _, []},
                {:==, _, [:dev]},
                _
              ]},
             Sourceror.Zipper.node(z)
           )
         end) do
      {:ok, zipper} ->
        {:ok, zipper}

      :error ->
        # Create new dev scope
        Igniter.Code.Common.add_code(zipper, """
        if Mix.env() == :dev do
          scope "/dev" do
            pipe_through :browser
          end
        end
        """)
    end
  end

  defp generate_migration(igniter, prefix) do
    # Generate the migration directly instead of delegating to vial.install
    # to avoid Igniter.Mix.Task behavior requirements
    app = Igniter.Project.Application.app_name(igniter)

    case Application.get_env(app, :ecto_repos) do
      [repo | _] ->
        repo_name = repo |> Module.split() |> List.last()
        timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
        filename = "#{timestamp}_add_vial_tables.exs"
        migrations_path = Path.join(["priv", "repo", "migrations", filename])

        content = migration_template(repo_name, prefix)

        Igniter.create_new_file(igniter, migrations_path, content)

      _ ->
        # No repo found, skip migration generation
        igniter
    end
  end

  defp migration_template(repo_name, prefix) do
    module_name = "#{repo_name}.Migrations.AddVialTables"

    prefix_option =
      if prefix == "public" do
        ""
      else
        "prefix: \"#{prefix}\""
      end

    """
    defmodule #{module_name} do
      use Ecto.Migration

      def up do
        Vial.Migrations.up(#{prefix_option})
      end

      def down do
        Vial.Migrations.down(#{prefix_option})
      end
    end
    """
  end
end
