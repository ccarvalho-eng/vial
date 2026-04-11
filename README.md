<div align="center">
  <img src="https://raw.githubusercontent.com/ccarvalho-eng/aludel/main/assets/images/logo.png" alt="Aludel Logo" width="220"/>
  <h1>Aludel</h1>
  <p><strong>LLM eval workbench for Phoenix.</strong></p>
  <p><em>Compare providers, version prompts, and run regression suites from one dashboard.</em></p>
  <p>
    <a href="https://hex.pm/packages/aludel"><img src="https://img.shields.io/hexpm/v/aludel.svg" alt="Hex.pm"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
    <a href="https://hexdocs.pm/aludel"><img src="https://img.shields.io/badge/documentation-gray" alt="Documentation"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ccarvalho-eng/aludel" alt="License"/></a>
  </p>
</div>

Aludel helps teams evaluate prompt and model behavior without building a custom dashboard first.

- Run the same prompt across OpenAI, Anthropic, Gemini, and Ollama.
- Compare output, latency, token usage, and cost side by side.
- Version prompts and track how changes affect results over time.
- Build suites with assertions and document attachments to catch regressions.
- Use it inside an existing Phoenix app or run it standalone.

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

## Documentation

The README covers the fastest path to value. Use the resources below for deeper setup and usage details.

- [Wiki](https://github.com/ccarvalho-eng/aludel/wiki)
- [HexDocs](https://hexdocs.pm/aludel)
- [Contributing Guide](CONTRIBUTING.md)
- [Issue Tracker](https://github.com/ccarvalho-eng/aludel/issues)
- [Discussions](https://github.com/ccarvalho-eng/aludel/discussions)

## Provider support

Aludel supports OpenAI, Anthropic, Google Gemini, and Ollama.

For embedded apps, configure provider keys in your host app:

```elixir
config :aludel, :llm,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  google_api_key: System.get_env("GOOGLE_API_KEY")
```

Ollama runs locally and does not require an API key.

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

![Aludel dashboard screenshot](https://github.com/user-attachments/assets/16e8caa6-81e2-44fa-b205-2dd9f6477760)

## License

[Apache License 2.0](LICENSE)
