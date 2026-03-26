import Config

# Configure test repo for Vial
config :vial,
  repo: Vial.Test.Repo,
  ecto_repos: [Vial.Test.Repo]

config :vial, Vial.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true,
  url: System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/vial_test"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vial, Vial.Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jHQ6deVasGy1rWMbTOBYSJIzswGrAo9e8AAvOVQdshCwwZMdQEk1XafnApBV/koE",
  server: false

# In test we don't send emails (config removed as Swoosh is not a dependency for embedded library)

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# LLM Provider API Keys - use bogus keys to prevent hitting real APIs in tests
config :vial, :llm,
  openai_api_key: "sk-test-fake-openai-key-for-testing",
  anthropic_api_key: "sk-ant-test-fake-anthropic-key-for-testing"
