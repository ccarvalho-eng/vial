import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      """

  config :aludel_dash, AludelDash.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      """

  config :aludel_dash, AludelDash.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base

  config :aludel_dash,
    basic_auth_user: System.get_env("BASIC_AUTH_USER"),
    basic_auth_pass: System.get_env("BASIC_AUTH_PASS"),
    read_only: System.get_env("READ_ONLY") == "true"
end
