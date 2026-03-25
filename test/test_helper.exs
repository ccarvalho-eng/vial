# Define Error HTML for tests
defmodule Vial.Web.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

# Define Error JSON for tests
defmodule Vial.Web.ErrorJSON do
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

# Configure endpoint for testing
Application.put_env(:vial, Vial.Web.Endpoint,
  check_origin: false,
  http: [port: 4002],
  live_view: [signing_salt: "test_signing_salt"],
  render_errors: [formats: [html: Vial.Web.ErrorHTML], layout: false],
  secret_key_base: String.duplicate("a", 64),
  server: false,
  url: [host: "localhost"]
)

# Define test router
defmodule Vial.Web.Test.Router do
  use Phoenix.Router

  import Vial.Web.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_flash
  end

  scope "/" do
    pipe_through :browser
    vial_dashboard("/")
  end
end

# Define test endpoint
defmodule Vial.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :vial

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session,
    store: :cookie,
    key: "_vial_test_key",
    signing_salt: "test_salt"

  plug Vial.Web.Test.Router
end

# Start test repo
Vial.Test.Repo.start_link()

# Start PubSub for tests
{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: Vial.PubSub}],
    strategy: :one_for_one
  )

# Start endpoint
Vial.Web.Endpoint.start_link()

# Set sandbox mode for test repo
Ecto.Adapters.SQL.Sandbox.mode(Vial.Test.Repo, :manual)

# Exclude integration tests that require external services or real API keys
# Run with: mix test --include ollama (if you have Ollama running)
# Run with: mix test --include anthropic_integration (requires ANTHROPIC_API_KEY)
# Run with: mix test --include openai_integration (requires OPENAI_API_KEY)
ExUnit.start(exclude: [:ollama, :anthropic_integration, :openai_integration])
