# Vial

**LLM prompt evaluation workbench**

[![CI](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml)
[![Security](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/ccarvalho-eng/vial/branch/main/graph/badge.svg)](https://codecov.io/gh/ccarvalho-eng/vial)

Run prompts across OpenAI, Anthropic, and Ollama simultaneously. Compare output quality, latency, token usage, and cost in real-time.

<img width="1663" height="966" alt="Screenshot 2026-03-20 at 15 08 04" src="https://github.com/user-attachments/assets/02e494cd-640e-4a6d-8875-2dbdc6e78714" />

---

## Features

- **Multi-provider comparison** — Run the same prompt across providers side-by-side. Track latency, token usage, and cost per run.
- **Prompt management** — Version-controlled templates with `{{variable}}` interpolation. Every edit creates an immutable new version. Supports tags and descriptions.
- **Evaluation suites** — Automated test cases with `contains`, `regex`, and `exact_match` assertions. Track pass rates and catch regressions over time.
- **Dashboard** — Live metrics as runs execute: cost trends, latency, and per-provider performance.

---

## Prerequisites

- Elixir 1.19.5+
- Erlang/OTP 28.4+
- PostgreSQL 17+
- Node.js 20+

Recommended: use [asdf](https://asdf-vm.com/) with the included `.tool-versions`.

---

## Setup

```bash
git clone https://github.com/ccarvalho-eng/vial.git
cd vial
mix deps.get
mix ecto.setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

---

## Providers

| Provider | Notes |
|---|---|
| **Ollama** ⭐ | Local, no API key required |
| **OpenAI** | [platform.openai.com](https://platform.openai.com) |
| **Anthropic** | [console.anthropic.com](https://console.anthropic.com) |

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

**4. Add a provider** — Go to **Providers → New Provider**, select the type, enter your API key, and configure model parameters.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit using [conventional commits](https://www.conventionalcommits.org/)
4. Run `mix precommit` before submitting
5. Open a Pull Request

---

## License

[Apache License 2.0](LICENSE)
