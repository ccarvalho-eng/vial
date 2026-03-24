defmodule Vial.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/vial"

  def project do
    [
      app: :vial,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        precommit: :test
      ],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],

      # Hex package configuration
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      # No mod - we're a library, not an application
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix and LiveView
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},

      # Database
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_enum, "~> 1.4"},

      # HTTP client for LLM providers
      {:req, "~> 0.5"},

      # JSON encoding/decoding
      {:jason, "~> 1.2"},

      # Code generation
      {:igniter, "~> 0.5", optional: true},

      # Assets (only at build time)
      {:esbuild, "~> 0.10", runtime: false},
      {:tailwind, "~> 0.3", runtime: false},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Test helpers
      {:lazy_html, ">= 0.1.0", only: :test},

      # Code quality and testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind vial", "esbuild vial"],
      "assets.deploy": [
        "tailwind vial --minify",
        "esbuild vial --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --check-unused",
        "format --check-formatted",
        "credo --strict",
        "sobelow --config .sobelow-conf",
        "test"
      ],
      "build.assets": ["vial.build_assets"]
    ]
  end

  defp description do
    """
    An embeddable Phoenix LiveView component for LLM prompt testing and evaluation.
    Provides a comprehensive dashboard for managing prompts, test suites, and provider comparisons.
    """
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
        lib
        priv/static/vial
        priv/repo/migrations
        CHANGELOG.md
        README.md
        LICENSE
        mix.exs
        .formatter.exs
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "example_host/README.md": [title: "Example Host Application"]
      ],
      groups_for_modules: [
        "Web Components": [~r/^VialWeb/],
        Contexts: [~r/^Vial\.(Prompts|Evals|Runs|Providers|Stats)/],
        Schemas: [~r/^Vial\.(Prompts|Evals|Runs|Providers)\./],
        "Migration Helpers": [Vial.Migrations]
      ]
    ]
  end
end
