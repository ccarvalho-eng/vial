# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :aludel,
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  run_execution_mode: :concurrent

config :aludel, :llm,
  max_concurrency: 3,
  request_timeout_ms: 120_000

config :aludel, Aludel.Storage, adapter: Aludel.Interfaces.Storage.Adapters.Local

config :ex_aws,
  json_codec: Jason

# Configures the endpoint
config :aludel, Aludel.Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Aludel.Web.ErrorHTML, json: Aludel.Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Aludel.PubSub,
  live_view: [signing_salt: "DBrn//Hy"]

# Mailer config removed as Swoosh is not a dependency for embedded library

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  aludel: [
    args:
      ~w(assets/js/app.js --bundle --target=es2022 --outdir=priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  aludel: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :provider_id, :reason]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
