defmodule AludelDash.MixProject do
  use Mix.Project

  def project do
    [
      app: :aludel_dash,
      version: "0.2.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {AludelDash.Application, []}
    ]
  end

  defp deps do
    [
      {:aludel, path: ".."},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.10", only: [:dev, :test], runtime: false},
      {:tailwind, "~> 0.3", only: [:dev, :test], runtime: false},
      {:bandit, "~> 1.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.19"},
      {:jason, "~> 1.2"}
    ]
  end

  defp releases do
    [
      aludel_dash: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
