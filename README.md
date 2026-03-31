<div align="center">
  <img src="https://raw.githubusercontent.com/ccarvalho-eng/aludel/main/assets/images/logo.png" alt="Aludel Logo" width="400"/>
  <h2>LLM Eval Workbench</h2>
  <p>
    <a href="https://hex.pm/packages/aludel"><img src="https://img.shields.io/hexpm/v/aludel.svg" alt="Hex.pm"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
    <a href="https://github.com/ccarvalho-eng/aludel/actions/workflows/security.yml"><img src="https://github.com/ccarvalho-eng/aludel/actions/workflows/security.yml/badge.svg" alt="Security"/></a>
    <a href="https://codecov.io/gh/ccarvalho-eng/aludel"><img src="https://codecov.io/gh/ccarvalho-eng/aludel/branch/main/graph/badge.svg" alt="codecov"/></a>
  </p>
  <p><em>From medieval Latin, derived from Arabic al-uthāl — a vessel for sublimation, where matter is refined through stages.</em><br/>
  <em>Like jinn answering invocation, LLMs respond to prompts; here, their nature is revealed, tested, and distilled.</em></p>
</div>

Run prompts across OpenAI, Anthropic, and Ollama simultaneously. Compare output quality, latency, token usage, and cost in real-time.

<img width="1331" height="958" alt="Screenshot 2026-03-30 at 10 09 31" src="https://github.com/user-attachments/assets/16e8caa6-81e2-44fa-b205-2dd9f6477760" />

---

## Requirements

**PostgreSQL 12+** is required. Aludel uses PostgreSQL-specific features:

- **JSONB columns** for storing variable values and assertions
- **`percentile_disc()`** window function for latency metrics (p50/p95)
- **`DATE()`** fragment for time-series aggregations

Other Ecto adapters (SQLite, MySQL) are not supported. If you attempt to use a different adapter, migrations will fail with column type errors.

---

## Features

- **Multi-provider comparison** — Run the same prompt across providers side-by-side. Track latency, token usage, and cost per run.
- **Prompt management** — Version-controlled templates with `{{variable}}` interpolation. Every edit creates an immutable new version. Supports tags and descriptions.
- **Evolution tracking** — Visualize prompt version performance over time. Track pass rates, cost, and latency trends across versions and providers.
- **Evaluation suites** — Visual test case editor with document attachments (PDF, images, CSV, JSON, TXT). Automated assertions including `contains`, `regex`, `exact_match`, and `json_field`. Track pass rates and catch regressions over time.
- **Dashboard** — Live metrics as runs execute: cost trends, latency, and per-provider performance.

---

## Installation

Aludel can be embedded into any Phoenix LiveView application as a self-contained dashboard.

### 1. Add dependency

Add Aludel to your `mix.exs`:

```elixir
def deps do
  [
    {:aludel, "~> 0.1"}
  ]
end
```

Run `mix deps.get`

### 2. Configure the repo

Add to `config/config.exs`:

```elixir
config :aludel, repo: YourApp.Repo
```

### 3. Install migrations

```bash
mix aludel.install
```

This copies Aludel's migrations to your `priv/repo/migrations/` directory.

### 4. Run migrations

```bash
mix ecto.migrate
```

### 5. Add router macro

In your `lib/your_app_web/router.ex`:

```elixir
use YourAppWeb, :router
import Aludel.Web.Router  # Add this line

# In development
if Mix.env() == :dev do
  scope "/dev" do
    pipe_through :browser
    aludel_dashboard "/aludel"  # Dashboard will be at /dev/aludel
  end
end

# Or in production (with authentication)
# scope "/admin" do
#   pipe_through [:browser, :require_admin]
#   aludel_dashboard "/aludel"
# end
```

The dashboard can be mounted at any path you choose. It's common to mount it under `/dev` in development or `/admin` in production (with proper authentication).

### 6. Configure API keys (optional)

Aludel reads provider API keys from application config. Add to your host app's config:

```elixir
# config/dev.exs (or config/runtime.exs for production)
config :aludel, :llm,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
```

Then set environment variables before starting the server:

```bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
mix phx.server
```

Ollama runs locally and requires no API keys.

### 7. Install ImageMagick (for Ollama PDF support)

If you want to test evaluation suites with PDF documents using **Ollama** vision models, install ImageMagick v7+:

```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick

# Check installation
magick -version
```

**Note:** PDF-to-image conversion is only required for **Ollama** vision models. **OpenAI** and **Anthropic Claude 4.5+** accept PDFs directly in their APIs without conversion. For Ollama, PDFs are converted to PNG (first page only, 150 DPI) before being sent to the model.

### 8. Seed demo data (optional)

```bash
mix aludel.seed
```

This populates the database with sample providers, prompts, and evaluation suites.

Visit the dashboard at your configured path (e.g., `http://localhost:4000/dev/aludel`).

---

## Standalone Mode

Aludel includes a standalone application in the `standalone/` directory for running the dashboard without embedding it in a Phoenix app.

### Setup

```bash
cd standalone
mix deps.get
mix ecto.create
mix ecto.migrate
mix aludel.seed  # Optional: add demo data
mix phx.server
```

Visit `http://localhost:4000`

### Configuration

Edit `standalone/config/dev.exs` to configure:

- **Database** — Default: `postgres://postgres:postgres@localhost/aludel_dash_dev`
- **Port** — Default: `4000`
- **API Keys** — Set `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` environment variables

### Production Deployment

```bash
# Set required environment variables
export DATABASE_URL=postgres://...
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...

# Optional: Enable basic auth
export BASIC_AUTH_USER=admin
export BASIC_AUTH_PASS=secret

# Optional: Set read-only mode
export READ_ONLY=true

# Run the app
MIX_ENV=prod mix release
_build/prod/rel/aludel_dash/bin/aludel_dash start
```

---

## Providers

| Provider | API Key Required | Configuration |
|---|---|---|
| **Ollama** ⭐ | No | Local models - works out of the box |
| **OpenAI** | Yes | Add `OPENAI_API_KEY` to `.env` ([Get key](https://platform.openai.com)) |
| **Anthropic** | Yes | Add `ANTHROPIC_API_KEY` to `.env` ([Get key](https://console.anthropic.com)) |

### Ollama quickstart

```bash
# Install from https://ollama.com, then:
ollama serve
ollama pull llama3  # or: mistral, codellama
mix run priv/repo/seeds.exs
```

Seeds create providers for Ollama, OpenAI, and Anthropic, along with 3 sample prompts and 3 evaluation suites with document attachments.

---

## Usage

**1. Create a prompt** — Go to **Prompts → New Prompt** and use `{{variable}}` syntax:

```
Explain {{topic}} in exactly 3 sentences.
```

**2. Run across providers** — Click **New Run**, fill in variables, select providers, and watch results stream in.

**3. Build evaluation suites** — Go to **Suites → New Suite**, add test cases with assertions, and run regression tests.

**4. Track evolution** — View the **Evolution** tab on any prompt to see how versions improve over time. Metrics show pass rates, cost, and latency per version and provider.

**5. Add a provider** — Go to **Providers → New Provider**, select the type, choose a model, and configure parameters (temperature, max_tokens, etc.). API keys are set via environment variables in `.env`.

---

## Development

### Working with assets (CSS/JS)

Aludel uses Tailwind CSS and esbuild for styling and JavaScript bundling.

**Asset compilation:**

Assets are compiled to the `priv/static/` directory and are **not tracked in git**. They are built automatically during development and packaged when publishing to Hex.

**Development workflow:**

Run the standalone app:

```bash
cd standalone
mix phx.server
```

**When you make changes:**

All changes require recompiling the aludel dependency and restarting the server:

```bash
# Terminal 1: Stop server (Ctrl+C)
# Terminal 2: Rebuild assets and recompile
mix assets.build && mix deps.compile aludel --force
# Terminal 1: Restart server
mix phx.server
```

This is due to path dependency limitations in Phoenix - the code reloader doesn't auto-recompile path dependencies, and assets are read at compile time for performance.

**Manual asset building:**

If you need to build assets manually:

```bash
mix assets.build  # Outputs to priv/static/app.css and priv/static/app.js
```

**Asset files:**
- Source CSS: `assets/css/app.css`
- Source JavaScript: `assets/js/app.js` and `assets/js/hooks/`
- Built assets: `priv/static/app.css` and `priv/static/app.js` (gitignored, included in Hex package)

**Publishing to Hex:**

Before publishing a new version, ensure assets are built:

```bash
mix assets.build
mix hex.build
```

The `priv/static/` directory is included in the Hex package so users get pre-compiled assets.

---

## Community

- **💬 [Discussions](https://github.com/ccarvalho-eng/aludel/discussions)** — Ask questions, share ideas, or discuss use cases
- **🐛 [Issues](https://github.com/ccarvalho-eng/aludel/issues)** — Report bugs or request features

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

**Quick start:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit using [conventional commits](https://www.conventionalcommits.org/)
4. Run `mix precommit` before submitting
5. Open a Pull Request

---

## License

[Apache License 2.0](LICENSE)
