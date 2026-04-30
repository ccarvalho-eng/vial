<div align="center">

  <img width="175" alt="aludel" src="https://github.com/user-attachments/assets/a5f90783-752a-4071-8c4f-78ff04d2f9bc" />
  
  <p><em>A Phoenix-native workbench for comparing providers, tracking prompt history, and running regression suites.</em></p>
  <p>
    <a href="https://hex.pm/packages/aludel"><img src="https://img.shields.io/hexpm/v/aludel.svg" alt="Hex.pm"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
    <a href="https://hexdocs.pm/aludel"><img src="https://img.shields.io/badge/docs-hexdocs-purple" alt="Hex Docs"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ccarvalho-eng/aludel" alt="License"/></a>
  </p>
</div>

Aludel gives teams a clean way to evaluate prompt and model behavior without inventing their own tooling first.

- Compare the same prompt across OpenAI, Anthropic, Gemini, and Ollama.
- Inspect output, latency, token usage, and cost side by side.
- Version prompts and see how changes affect results over time.
- Run evaluation suites with assertions and document attachments.
- Use it inside an existing Phoenix app or run it standalone.

## Why Aludel

Most teams evaluating LLM behavior end up with some combination of scripts, spreadsheets, and ad hoc dashboards. Aludel brings that work into one place with a UI that is practical enough for day-to-day iteration.

- **Provider comparison**: run the same input across models and vendors in one view.
- **Prompt history**: keep prompt changes traceable instead of losing them in copy-pasted variants.
- **Regression coverage**: turn important scenarios into repeatable suites with assertions.
- **Phoenix-native deployment**: mount it in your app or run it as a standalone dashboard.

## Structured Output Scoring

Suites support strict string assertions and structured JSON checks.

For structured outputs, use `json_deep_compare` to score partial matches instead of forcing all-or-nothing pass/fail outcomes.

```json
[
  {
    "type": "json_deep_compare",
    "expected": {
      "status": "ok",
      "customer": {
        "name": "Jane",
        "tier": "gold"
      }
    },
    "threshold": 75.0
  }
]
```

Aludel stores field-level comparison details, per-test match scores, and suite-run average scores so prompt evolution and exports can track structured output quality over time.

## Quick Start

### Embed in an existing Phoenix app

Requirements:
- Elixir and Phoenix
- PostgreSQL 12+

Aludel depends on PostgreSQL-specific features, including `JSONB`, `percentile_disc()`, and `DATE()`-based aggregations. SQLite and MySQL are not supported.

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

If you want to run Aludel by itself:

```bash
git clone https://github.com/ccarvalho-eng/aludel.git
cd aludel/standalone
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

To populate the local database with sample prompts, providers, and suites:

```bash
mix aludel.seed
```

Visit `http://localhost:4000`.

## Provider support

Aludel supports OpenAI, Anthropic, Google Gemini, and Ollama.

| Provider | API key required | Notes |
|---|---|---|
| OpenAI | Yes | Configure with `OPENAI_API_KEY` |
| Anthropic | Yes | Configure with `ANTHROPIC_API_KEY` |
| Google Gemini | Yes | Configure with `GOOGLE_API_KEY` |
| Ollama | No | Runs locally |

For embedded apps, configure provider keys in `config/runtime.exs`:

```elixir
# In config/runtime.exs
config :aludel, :llm,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  google_api_key: System.get_env("GOOGLE_API_KEY")
```

Ollama runs locally and does not require an API key.

## Document Storage

Uploaded test case documents go through `Aludel.Storage`.

- Development uses the local filesystem adapter from `config/dev.exs`.
- Production uses `config/runtime.exs` and requires `ALUDEL_STORAGE_BACKEND`.

### Development storage

Development stores uploaded documents on the local filesystem.

### Production storage

Set `ALUDEL_STORAGE_BACKEND` to `aws` or `gcs`.

For AWS S3:

```bash
export ALUDEL_STORAGE_BACKEND=aws
export AWS_S3_BUCKET=aludel-uploads
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

For Google Cloud Storage:

```bash
export ALUDEL_STORAGE_BACKEND=gcs
export GCS_BUCKET=aludel-uploads
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
```

If your GCS bucket requires requester-pays access, also set:

```bash
export GCS_USER_PROJECT=your-billing-project-id
```

The GCS adapter uses `Goth` with standard Google application credentials.
`GOOGLE_APPLICATION_CREDENTIALS_JSON` also works if you prefer inline JSON.

## Documentation

The README is intentionally optimized for first contact. For deeper setup, usage, and contribution details:

- [Wiki](https://github.com/ccarvalho-eng/aludel/wiki)
- [HexDocs](https://hexdocs.pm/aludel)
- [Contributing Guide](https://github.com/ccarvalho-eng/aludel/blob/main/CONTRIBUTING.md)
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

For standalone development, run the app from the `standalone` directory:

```bash
cd standalone
mix phx.server
```

If you change frontend assets, rebuild them from the repo root and restart the standalone server:

```bash
mix assets.build
mix compile --force
```

## License

[Apache License 2.0](https://github.com/ccarvalho-eng/aludel/blob/main/LICENSE)
