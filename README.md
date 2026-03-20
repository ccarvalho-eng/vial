# Vial

**LLM prompt evaluation workbench**

[![Elixir](https://img.shields.io/badge/Elixir-1.19-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-orange?logo=phoenix-framework&logoColor=white)](https://phoenixframework.org)
[![CI](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml)
[![Security](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/ccarvalho-eng/vial/branch/main/graph/badge.svg)](https://codecov.io/gh/ccarvalho-eng/vial)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

**Compare LLM providers side-by-side.** Test prompts across OpenAI, Anthropic, and Ollama with real-time streaming results, cost tracking, and automated evaluation suites.

<img width="1663" height="966" alt="Screenshot 2026-03-20 at 15 08 04" src="https://github.com/user-attachments/assets/02e494cd-640e-4a6d-8875-2dbdc6e78714" />

---

## Features

### Multi-Provider Comparison
Run the same prompt across multiple LLM providers simultaneously and compare:
- **Output quality** - See responses side-by-side
- **Performance** - Compare latency and token usage
- **Cost** - Track spend per provider with automatic cost calculation

### Prompt Management
- Version-controlled prompt templates with `{{variable}}` interpolation
- Immutable version history - every edit creates a new version
- Organize with tags and descriptions

### Evaluation Suites
- Automated testing with assertions (`contains`, `regex`, `exact_match`)
- Track pass rates over time
- Regression testing for prompt changes

### Provider Support
- **OpenAI** (GPT-4, GPT-3.5, etc.)
- **Anthropic** (Claude 3.5 Sonnet, Opus, etc.)
- **Ollama** (Local models - Llama 3, Mistral, etc.)

### Real-time Dashboard
- Live metrics as runs execute
- Cost tracking and trends
- Performance analytics per provider

---

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.19.5+
- [Erlang/OTP](https://www.erlang.org/downloads) 28.4+
- [PostgreSQL](https://www.postgresql.org/download/) 17+
- [Node.js](https://nodejs.org/) 20+ (for asset compilation)

**Recommended**: Use [asdf](https://asdf-vm.com/) with the included `.tool-versions` file to manage versions.

---

## Setup

**1. Clone and install dependencies**

```bash
git clone https://github.com/ccarvalho-eng/vial.git
cd vial
mix deps.get
```

**2. Set up the database**

```bash
mix ecto.setup
```

**3. Start the server**

```bash
mix phx.server
```

Visit [localhost:4000](http://localhost:4000)

---

## Providers

Vial supports multiple LLM providers. Get started locally with **Ollama** — no API key required.

<table>
<tr>
<th align="center">Ollama ⭐</th>
<th align="center">OpenAI</th>
<th align="center">Anthropic</th>
</tr>
<tr>
<td align="center">Local, no API key needed</td>
<td align="center"><a href="https://platform.openai.com">platform.openai.com</a></td>
<td align="center"><a href="https://console.anthropic.com">console.anthropic.com</a></td>
</tr>
</table>

### Using Ollama locally

```bash
# Install from https://ollama.com, then:
ollama serve
ollama pull llama3      # or: mistral, codellama
mix run priv/repo/seeds.exs
```

The seeds create a default Ollama provider, 3 sample prompts, and 3 evaluation suites with test cases.

---

## Quick Start

**1. Create a prompt** with variables:

Go to **Prompts → New Prompt**:
```
Explain {{topic}} in exactly 3 sentences.
```

**2. Run it across multiple providers:**

- Click **New Run** on your prompt
- Fill in variables (e.g., `topic = "quantum computing"`)
- Select multiple providers (OpenAI, Anthropic, Ollama)
- Watch results stream in real-time, side-by-side

**3. Build evaluation suites:**

- Go to **Suites → New Suite**
- Add test cases with expected outputs and assertions
- Run regression tests to catch prompt degradation

**4. Monitor performance:**

- Track costs, latency, and pass rates on the **Dashboard**
- Compare provider performance over time

---

## Adding Other Providers

1. Navigate to **Providers** in the UI
2. Click **New Provider**
3. Select your provider type and enter your API key
4. Configure model parameters (temperature, max\_tokens, etc.)

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using [conventional commits](https://www.conventionalcommits.org/)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Before submitting:
- Run `mix precommit` to ensure tests pass and code is formatted
- Update documentation if needed

---

## Support

- [Report issues](https://github.com/ccarvalho-eng/vial/issues)

---

## License

Licensed under the [Apache License 2.0](LICENSE).
