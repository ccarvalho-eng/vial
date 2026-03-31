import Config

config :aludel, repo: AludelDash.Repo

config :aludel_dash, ecto_repos: [AludelDash.Repo]

config :aludel_dash, AludelDash.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [view: AludelDash.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: AludelDash.PubSub,
  live_view: [signing_salt: "aludel_dash"]

# Configure esbuild to build parent aludel assets
config :esbuild,
  version: "0.25.4",
  aludel: [
    args:
      ~w(assets/js/app.js --bundle --target=es2022 --outdir=dist --external:/fonts/* --external:/images/*),
    cd: Path.expand("../..", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../../deps", __DIR__)}
  ]

# Configure tailwind to build parent aludel assets
config :tailwind,
  version: "4.1.7",
  aludel: [
    args: ~w(
      --input=css/app.css
      --output=../dist/app.css
    ),
    cd: Path.expand("../../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
