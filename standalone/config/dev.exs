import Config

config :vial_dash, VialDash.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "vial_dash_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  priv: "../priv/repo"

config :vial_dash, VialDash.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: "LOCAL_DEV_SECRET_PLEASE_CHANGE_IN_PROD",
  watchers: []
