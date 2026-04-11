<div align="center">
  <img src="https://raw.githubusercontent.com/ccarvalho-eng/aludel/main/assets/images/logo.png" alt="Aludel Logo" width="220"/>
  <h1>Aludel</h1>
  <p><strong>LLM eval workbench for Phoenix.</strong></p>
  <p>
    Compare providers side by side, version prompts, and run regression suites from a dashboard that can live inside your app or run standalone.
  </p>
  <p>
    <a href="https://hex.pm/packages/aludel"><img src="https://img.shields.io/hexpm/v/aludel.svg" alt="Hex.pm"/></a>
    <a href="https://hexdocs.pm/aludel"><img src="https://img.shields.io/badge/docs-hexdocs-6e4aff" alt="HexDocs"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/security.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/security.yml/badge.svg" alt="Security"/></a>
    <a href="https://codecov.io/gh/ccarvalho-eng/aludel"><img src="https://codecov.io/gh/ccarvalho-eng/aludel/branch/main/graph/badge.svg" alt="Codecov"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ccarvalho-eng/aludel" alt="License"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/discussions"><img src="https://img.shields.io/github/discussions/ccarvalho-eng/aludel" alt="Discussions"/></a>
  </p>
  <p><em>Named for the vessel used in sublimation: a place where raw material is refined through stages.</em></p>
</div>

![Aludel dashboard screenshot](https://github.com/user-attachments/assets/16e8caa6-81e2-44fa-b205-2dd9f6477760)

## What Aludel does

Aludel helps you evaluate prompt and model behavior with less spreadsheet work and less hand-rolled glue code.

- Compare the same prompt across OpenAI, Anthropic, Gemini, and Ollama.
- Track output quality, latency, token usage, and cost in one place.
- Version prompts over time and inspect how changes affect results.
- Build evaluation suites with assertions and document attachments to catch regressions.
- Run as an embedded Phoenix dashboard or as a standalone app.

## Why teams use it

- **Provider comparison**: run the same input across multiple providers side by side.
- **Prompt versioning**: treat prompt changes like product changes, with history and traceability.
- **Regression testing**: keep suites of test cases and assertions for repeatable checks.
- **Operational visibility**: see cost, latency, and pass-rate trends without custom tooling.

## Quick Start

### Embed in an existing Phoenix app

**Requirements**

- Elixir and Phoenix
- PostgreSQL 12+

Aludel currently depends on PostgreSQL-specific features, including `JSONB`, `percentile_disc()`, and `DATE()`-based aggregations. SQLite and MySQL are not supported.

**1. Add the dependency**

```elixir
def deps do
  [
    {:aludel, "~> 0.1"}
  ]
end
```

```bash
mix deps.get
```

**2. Configure the repo**

```elixir
config :aludel, repo: YourApp.Repo
```

**3. Install and run migrations**

```bash
mix aludel.install
mix ecto.migrate
```

**4. Mount the dashboard**

```elixir
use YourAppWeb, :router
import Aludel.Web.Router

if Mix.env() == :dev do
  scope "/dev" do
    pipe_through :browser
    aludel_dashboard "/aludel"
  end
end
```

**5. Start using it**

Visit your configured path, for example `http://localhost:4000/dev/aludel`.

### Standalone mode

If you want to evaluate without embedding Aludel into another app:

```bash
cd standalone
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

Visit `http://localhost:4000`.

## Provider support

| Provider | API Key Required | Notes |
|---|---|---|
| **Ollama** | No | Local-first, works out of the box |
| **OpenAI** | Yes | Configure via `OPENAI_API_KEY` |
| **Anthropic** | Yes | Configure via `ANTHROPIC_API_KEY` |
| **Google Gemini** | Yes | Configure via `GOOGLE_API_KEY` |

For embedded apps, configure keys in your host application's config:

```elixir
config :aludel, :llm,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  google_api_key: System.get_env("GOOGLE_API_KEY")
```

Ollama runs locally and does not require an API key.

## Typical workflow

1. Create a prompt with `{{variable}}` placeholders.
2. Run it across multiple providers.
3. Compare responses, latency, token usage, and cost.
4. Turn important checks into suites with assertions.
5. Track performance over time as prompts evolve.

## Documentation

The README covers the fastest path to value. Use the docs below for deeper setup and usage details.

- [Wiki](https://github.com/ccarvalho-eng/aludel/wiki)
- [HexDocs](https://hexdocs.pm/aludel)
- [Contributing Guide](CONTRIBUTING.md)
- [Issue Tracker](https://github.com/ccarvalho-eng/aludel/issues)
- [Discussions](https://github.com/ccarvalho-eng/aludel/discussions)

## Development

For local development:

```bash
mix deps.get
mix compile
mix test
mix precommit
```

If you are changing frontend assets:

```bash
mix assets.build
mix compile --force
```

For full-app development with watchers, run the standalone app:

```bash
cd standalone
mix phx.server
```

## License

[Apache License 2.0](LICENSE)
