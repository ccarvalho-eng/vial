# Vial

**LLM prompt evaluation workbench**

[![CI](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml)
[![Security](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/ccarvalho-eng/vial/branch/main/graph/badge.svg)](https://codecov.io/gh/ccarvalho-eng/vial)

Run prompts across OpenAI, Anthropic, and Ollama simultaneously. Compare output quality, latency, token usage, and cost in real-time.

<img width="1371" height="960" alt="Screenshot 2026-03-22 at 18 45 00" src="https://github.com/user-attachments/assets/7d9c43ba-54be-428b-8e44-1762de57b99f" />

---

## Features

- **Multi-provider comparison** — Run the same prompt across providers side-by-side. Track latency, token usage, and cost per run.
- **Prompt management** — Version-controlled templates with `{{variable}}` interpolation. Every edit creates an immutable new version. Supports tags and descriptions.
- **Evolution tracking** — Visualize prompt version performance over time. Track pass rates, cost, and latency trends across versions and providers.
- **Evaluation suites** — Automated test cases with `contains`, `regex`, and `exact_match` assertions. Track pass rates and catch regressions over time.
- **Dashboard** — Live metrics as runs execute: cost trends, latency, and per-provider performance.

---

## Installation

Vial can be embedded into any Phoenix LiveView application as a self-contained dashboard.

### 1. Add dependency

Add Vial to your `mix.exs`:

```elixir
def deps do
  [
    {:vial, path: "../vial"}  # For local development
    # Soon: {:vial, "~> 0.1"}  # When published to Hex
  ]
end
```

Run `mix deps.get`

### 2. Configure the repo

Add to `config/config.exs`:

```elixir
config :vial, repo: YourApp.Repo
```

### 3. Run migrations

```bash
mix ecto.migrate
```

### 4. Add router macro

In your `lib/your_app_web/router.ex`:

```elixir
use YourAppWeb, :router
import Vial.Web.Router  # Add this line

scope "/admin" do
  pipe_through :browser
  vial_dashboard "/vial"  # Dashboard will be at /admin/vial
end
```

The dashboard can be mounted at any path you choose.

### 5. Configure API keys (optional)

Vial reads provider API keys from application config. Add to your host app's config:

```elixir
# config/dev.exs (or config/runtime.exs for production)
config :vial, :llm,
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

### 6. Seed demo data (optional)

```bash
mix vial.seed
```

This populates the database with sample providers, prompts, and evaluation suites.

Visit the dashboard at your configured path (e.g., `http://localhost:4000/admin/vial`).

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

Seeds create a default Ollama provider, 3 sample prompts, and 3 evaluation suites.

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

Vial uses Tailwind CSS and esbuild for styling and JavaScript bundling.

**After making changes to CSS or JS files:**

```bash
# 1. Rebuild assets (from vial directory)
mix assets.build

# 2. If working on an embedded installation, recompile the dependency
cd ../your_host_app
mix deps.compile vial --force

# 3. Restart the Phoenix server to pick up changes
```

**Asset files:**
- CSS: `assets/css/app.css`
- JavaScript: `assets/js/app.js` and `assets/js/hooks/`
- Built assets go to: `priv/static/assets/`

**Live development workflow:**

For faster iteration, you can use the watcher in development mode:

```bash
# In the vial directory
mix phx.server  # Starts asset watchers automatically
```

The asset watchers will automatically rebuild CSS/JS on file changes.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit using [conventional commits](https://www.conventionalcommits.org/)
4. Run `mix precommit` before submitting
5. Open a Pull Request

**For changes to CSS/JS:** Make sure to rebuild assets with `mix assets.build` before committing. Built assets in `priv/static/assets/` are gitignored - only source files in `assets/` are tracked.

---

## License

[Apache License 2.0](LICENSE)
