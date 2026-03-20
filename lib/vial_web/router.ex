defmodule VialWeb.Router do
  use VialWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VialWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VialWeb do
    pipe_through :browser

    live "/", DashboardLive, :index

    live "/prompts", PromptLive.Index, :index
    live "/prompts/new", PromptLive.New, :new
    live "/prompts/:id/edit", PromptLive.New, :edit
    live "/prompts/:id", PromptLive.Show, :show

    live "/runs/new", RunLive.New, :new
    live "/runs/:id", RunLive.Show, :show

    live "/suites", SuiteLive.Index, :index
    live "/suites/new", SuiteLive.New, :new
    live "/suites/:id/edit", SuiteLive.New, :edit
    live "/suites/:id", SuiteLive.Show, :show

    live "/providers", ProviderLive.Index, :index
    live "/providers/new", ProviderLive.New, :new
    live "/providers/:id/edit", ProviderLive.New, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", VialWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vial, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VialWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
