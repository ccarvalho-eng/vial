import Config

config :vial, ecto_repos: [Vial.Repo]

if File.exists?("#{__DIR__}/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
