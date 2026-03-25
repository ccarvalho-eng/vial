import Config

config :vial, repo: VialDash.Repo

config :vial_dash, ecto_repos: [VialDash.Repo]

config :vial_dash, VialDash.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [view: VialDash.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: VialDash.PubSub,
  live_view: [signing_salt: "vial_dash"]

import_config "#{config_env()}.exs"
