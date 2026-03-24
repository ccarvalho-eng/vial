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
    * `--seed` - Run seed task after installation (default: false)

  ## Examples

      # Basic installation
      mix igniter.install vial

      # Install at custom path
      mix igniter.install vial --path /internal/prompts

      # Install with database prefix for multi-tenancy
      mix igniter.install vial --prefix tenant_schema

      # Dev-only installation
      mix igniter.install vial --dev-only

      # Install and seed example data
      mix igniter.install vial --seed

  ## What it does

  1. Adds TaskSupervisor to your application supervision tree
  2. Imports Vial.Router in your router
  3. Mounts vial_dashboard at the specified path
  4. Adds Vial.Static plug to your endpoint
  5. Generates the Vial database migration
  6. Optionally runs seed task to populate example data
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :igniter,
      # Dependencies that must be installed before this task can run
      adds_deps: [],
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
        dev_only: :boolean,
        seed: :boolean
      ],
      # Default values for options
      defaults: [
        prefix: "public",
        dev_only: false,
        seed: false
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
    run_seed = options[:seed]

    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Project.Module.module_name(igniter, "#{app_name}_web")
    repo_module = find_repo_module(igniter, app_name)

    igniter
    |> add_task_supervisor(app_name)
    |> add_vial_static_plug(web_module)
    |> setup_router(web_module, repo_module, app_name, path, dev_only)
    |> generate_migration(prefix)
    |> maybe_run_seed(run_seed, repo_module)
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
    |> case do
      {:ok, igniter} ->
        igniter

      {:error, igniter} ->
        # Already exists, continue
        igniter
    end
  end

  defp add_vial_static_plug(igniter, web_module) do
    endpoint_module = Module.concat(web_module, "Endpoint")

    Igniter.Project.Module.find_and_update_module!(igniter, endpoint_module, fn
      zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Function.move_to_function_call_in_current_scope(
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
          # Insert Vial.Static before the app's Plug.Static
          Igniter.Code.Common.add_code(zipper, """
          # Serve Vial static assets
          plug Vial.Static
          """)
        else
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
      with {:ok, zipper} <-
             Igniter.Code.Common.add_code(zipper, "import Vial.Router", :before) do
        {:ok, zipper}
      end
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
    with {:ok, zipper} <-
           Igniter.Code.Common.move_to(zipper, fn z ->
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
      {:ok, zipper}
    else
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
    # Queue up the migration task to run
    Igniter.compose_task(igniter, "vial.install", ["--prefix", prefix])
  end

  defp maybe_run_seed(igniter, true, _repo_module) do
    Igniter.compose_task(igniter, "vial.seed", [])
  end

  defp maybe_run_seed(igniter, false, _repo_module) do
    igniter
  end
end
