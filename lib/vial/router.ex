defmodule Vial.Router do
  @moduledoc """
  Router macro for embedding Vial into Phoenix applications.

  ## Usage

  In your Phoenix router:

      import Vial.Router

      scope "/admin" do
        pipe_through [:browser, :authenticated]

        vial_dashboard "/vial",
          repo: MyApp.Repo,
          openai_api_key: System.get_env("OPENAI_API_KEY")
      end

  ## Options

    * `:repo` (required) - The Ecto repo module to use for database operations
    * `:task_supervisor` (required) - The Task.Supervisor module for running async operations
    * `:openai_api_key` - OpenAI API key for LLM operations. Can be a string,
      a function `{Module, :function, args}`, or `nil` to disable LLM features
    * `:on_mount` - Additional LiveView on_mount hooks for authentication/authorization
    * `:prefix` - Database schema prefix for Vial tables (defaults to "public")
    * `:resolver` - Module implementing `Vial.Resolver` behavior for access control
    * `:csp_nonce_assign_key` - Assign key for CSP nonce if using Content Security Policy

  ## Authentication

  Vial relies entirely on your application's authentication pipeline.
  Use standard Phoenix pipelines to protect the dashboard:

      pipeline :admin_only do
        plug :ensure_authenticated
        plug :ensure_admin_role
      end

      scope "/admin" do
        pipe_through [:browser, :admin_only]
        vial_dashboard "/vial", repo: MyApp.Repo
      end

  For more granular access control, implement a resolver module:

      defmodule MyApp.VialResolver do
        use Vial.Resolver

        def can_view_dashboard?(user), do: user.role in [:admin, :developer]
        def can_modify_prompts?(user), do: user.role == :admin
        def can_run_tests?(user), do: true
      end

  Then pass it as an option:

      vial_dashboard "/vial",
        repo: MyApp.Repo,
        resolver: MyApp.VialResolver
  """

  @doc """
  Mounts the Vial dashboard at the specified path.
  """
  defmacro vial_dashboard(path, opts \\ []) do
    opts =
      Keyword.validate!(opts, [
        :repo,
        :task_supervisor,
        :openai_api_key,
        :on_mount,
        :prefix,
        :resolver,
        :csp_nonce_assign_key
      ])

    unless opts[:repo] do
      raise ArgumentError, """
      The :repo option is required for vial_dashboard.

      Example:
        vial_dashboard "/vial", repo: MyApp.Repo
      """
    end

    quote bind_quoted: [path: path, opts: opts] do
      scope path, alias: false, as: false do
        # Configure on_mount hooks
        on_mount_hooks = [
          {Vial.Hooks, :inject_config}
          | Keyword.get(opts, :on_mount, [])
        ]

        Phoenix.LiveView.Router.live_session :vial_dashboard,
          on_mount: on_mount_hooks,
          root_layout: {VialWeb.Layouts, :root},
          session: %{"vial_config" => opts, "vial_base_path" => path} do
          Phoenix.LiveView.Router.live("/", VialWeb.DashboardLive, :index)

          # Prompts
          Phoenix.LiveView.Router.live("/prompts", VialWeb.PromptLive.Index, :index)
          Phoenix.LiveView.Router.live("/prompts/new", VialWeb.PromptLive.New, :new)
          Phoenix.LiveView.Router.live("/prompts/:id", VialWeb.PromptLive.Show, :show)
          Phoenix.LiveView.Router.live("/prompts/:id/edit", VialWeb.PromptLive.New, :edit)

          Phoenix.LiveView.Router.live(
            "/prompts/:id/evolution",
            VialWeb.PromptLive.Evolution,
            :show
          )

          # Runs
          Phoenix.LiveView.Router.live("/runs/new", VialWeb.RunLive.New, :new)
          Phoenix.LiveView.Router.live("/runs/:id", VialWeb.RunLive.Show, :show)

          # Test Suites
          Phoenix.LiveView.Router.live("/suites", VialWeb.SuiteLive.Index, :index)
          Phoenix.LiveView.Router.live("/suites/new", VialWeb.SuiteLive.New, :new)
          Phoenix.LiveView.Router.live("/suites/:id", VialWeb.SuiteLive.Show, :show)
          Phoenix.LiveView.Router.live("/suites/:id/edit", VialWeb.SuiteLive.New, :edit)

          # Providers
          Phoenix.LiveView.Router.live("/providers", VialWeb.ProviderLive.Index, :index)
          Phoenix.LiveView.Router.live("/providers/new", VialWeb.ProviderLive.New, :new)
          Phoenix.LiveView.Router.live("/providers/:id/edit", VialWeb.ProviderLive.New, :edit)
        end
      end
    end
  end
end
