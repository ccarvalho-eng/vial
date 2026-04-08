<div align="center">
  <br/>
  <br/>
  <br/>
  <img src="https://raw.githubusercontent.com/ccarvalho-eng/aludel/main/assets/images/logo.png" alt="Aludel Logo" width="250"/>
  <br/>
  <br/>
  <br/>
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

Run prompts across OpenAI, Anthropic, Google Gemini, and Ollama simultaneously. Compare output quality, latency, token usage, and cost in real-time.

![Aludel dashboard screenshot](https://github.com/user-attachments/assets/16e8caa6-81e2-44fa-b205-2dd9f6477760)

---

## Table of Contents

- [Requirements](#requirements)
- [Features](#features)
- [Installation](#installation)
  - [1. Add dependency](#1-add-dependency)
  - [2. Configure the repo](#2-configure-the-repo)
  - [3. Install migrations](#3-install-migrations)
  - [4. Run migrations](#4-run-migrations)
  - [5. Add router macro](#5-add-router-macro)
  - [6. Configure API keys (optional)](#6-configure-api-keys-optional)
  - [7. Install ImageMagick (for Ollama PDF support)](#7-install-imagemagick-for-ollama-pdf-support)
  - [8. Seed demo data (optional)](#8-seed-demo-data-optional)
- [Standalone Mode](#standalone-mode)
  - [Setup](#setup)
  - [Configuration](#configuration)
  - [Docker](#docker)
  - [Production Deployment](#production-deployment)
- [Providers](#providers)
  - [Ollama quickstart](#ollama-quickstart)
- [Usage](#usage)
- [Development](#development)
  - [Working with assets (CSS/JS)](#working-with-assets-cssjs)
- [Community](#community)
- [Contributing](#contributing)
- [Star History](#star-history)
- [License](#license)

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
- **Prompt management** — Version-controlled templates with `{{variable}}` interpolation. Every edit creates an immutable new version. Supports tags, descriptions, and project organization.
- **Evolution tracking** — Visualize prompt version performance over time. Track pass rates, cost, and latency trends across versions and providers.
- **Evaluation suites** — Visual test case editor with document attachments (PDF, images, CSV, JSON, TXT). Automated assertions including `contains`, `regex`, `exact_match`, and `json_field`. Organize suites into projects, track pass rates, and catch regressions over time.
- **Dashboard** — Live metrics as runs execute: cost trends, latency, and per-provider performance.

---

## Installation

Aludel can be embedded into any Phoenix LiveView application as a self-contained dashboard.

The embeddable dashboard approach borrows a few patterns from [Oban Web](https://github.com/oban-bg/oban_web), which helped shape how Aludel mounts cleanly inside an existing Phoenix app.

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
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  google_api_key: System.get_env("GOOGLE_API_KEY")
```

Then set environment variables before starting the server:

```bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export GOOGLE_API_KEY=...
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

**Note:** PDF-to-image conversion is required for **Ollama** and **OpenAI** vision models. Only **Anthropic Claude 4.5+** accepts PDFs directly in its API without conversion. For Ollama and OpenAI, PDFs are converted to PNG (first page only, 150 DPI) before being sent to the model.

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
- **API Keys** — Set `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GOOGLE_API_KEY` environment variables

### Docker

A `docker-compose.yaml` is provided at the project root for running the standalone app with PostgreSQL in containers.

```bash
# 1. Copy the example env file and edit as needed
cp .env.example .env

# 2. Start the app (builds the image on first run)
docker-compose up -d

# 3. Visit http://localhost:4000
```

Environment variables are loaded from the `.env` file. Edit it to configure API keys, basic auth, and other settings. See `.env.example` for all available options.

To stop and remove all data:

```bash
docker-compose down -v
```

### Production Deployment

```bash
# Set required environment variables
export DATABASE_URL=postgres://...
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export GOOGLE_API_KEY=...

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
| **Google Gemini** | Yes | Add `GOOGLE_API_KEY` to `.env` ([Get key](https://aistudio.google.com/apikey)) |

### Ollama quickstart

```bash
# Install from https://ollama.com, then:
ollama serve
ollama pull llama3  # or: mistral, codellama
mix run priv/repo/seeds.exs
```

Seeds create providers for Ollama, OpenAI, Anthropic, and Google Gemini, along with 3 sample prompts and 3 evaluation suites with document attachments.

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

**After making changes to CSS or JS files:**

```bash
# 1. Rebuild assets (from aludel directory)
mix assets.build

# 2. Force recompile to pick up new asset hashes
mix compile --force

# 3. If working on an embedded installation, recompile the dependency
cd ../your_host_app
mix deps.compile aludel --force

# 4. Restart the Phoenix server to pick up changes
```

**Asset files:**
- CSS: `assets/css/app.css`
- JavaScript: `assets/js/app.js` and `assets/js/hooks/`
- Built assets: `priv/static/app.css` and `priv/static/app.js` (committed to git)

**Live development workflow:**

For faster iteration during development, you can use Mix tasks with watchers:

```bash
# Watch and rebuild CSS on changes
mix tailwind aludel --watch

# Watch and rebuild JS on changes (in another terminal)
mix esbuild aludel --watch
```

Alternatively, run the standalone app for a full development server:

```bash
cd standalone
mix phx.server  # Starts asset watchers automatically
```

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

## Star History

<a href="https://www.star-history.com/?repos=ccarvalho-eng/aludel&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=ccarvalho-eng/aludel&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=ccarvalho-eng/aludel&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=ccarvalho-eng/aludel&type=date&legend=top-left" />
 </picture>
</a>

---

## License

[Apache License 2.0](LICENSE)
