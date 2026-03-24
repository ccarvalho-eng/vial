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
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        # Static assets route for Vial's pre-compiled CSS/JS
        get "/vial-assets/*path", Vial.Static, :serve

        # Configure on_mount hooks
        on_mount_hooks = [
          {Vial.Hooks, :inject_config, [opts]}
          | Keyword.get(opts, :on_mount, [])
        ]

        live_session :vial_dashboard,
          on_mount: on_mount_hooks,
          root_layout: {VialWeb.Layouts, :root} do
          live "/", VialWeb.DashboardLive, :index

          # Prompts
          live "/prompts", VialWeb.PromptLive.Index, :index
          live "/prompts/new", VialWeb.PromptLive.New, :new
          live "/prompts/:id", VialWeb.PromptLive.Show, :show
          live "/prompts/:id/edit", VialWeb.PromptLive.New, :edit
          live "/prompts/:id/evolution", VialWeb.PromptLive.Evolution, :show

          # Runs
          live "/runs/new", VialWeb.RunLive.New, :new
          live "/runs/:id", VialWeb.RunLive.Show, :show

          # Test Suites
          live "/suites", VialWeb.SuiteLive.Index, :index
          live "/suites/new", VialWeb.SuiteLive.New, :new
          live "/suites/:id", VialWeb.SuiteLive.Show, :show
          live "/suites/:id/edit", VialWeb.SuiteLive.New, :edit

          # Providers
          live "/providers", VialWeb.ProviderLive.Index, :index
          live "/providers/new", VialWeb.ProviderLive.New, :new
          live "/providers/:id/edit", VialWeb.ProviderLive.New, :edit
        end
      end
    end
  end
end
