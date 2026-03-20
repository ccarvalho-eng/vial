# Vial

**LLM prompt evaluation workbench**

[![Elixir](https://img.shields.io/badge/Elixir-1.19-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org)
[![Erlang/OTP](https://img.shields.io/badge/Erlang%2FOTP-28-A90533?logo=erlang&logoColor=white)](https://www.erlang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-orange?logo=phoenix-framework&logoColor=white)](https://phoenixframework.org)
[![CI](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml)
[![Security](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/ccarvalho-eng/vial/branch/main/graph/badge.svg)](https://codecov.io/gh/ccarvalho-eng/vial)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Test, compare, and monitor prompt behavior across LLM providers.

<img width="1663" height="966" alt="Screenshot 2026-03-20 at 15 08 04" src="https://github.com/user-attachments/assets/02e494cd-640e-4a6d-8875-2dbdc6e78714" />

---

## Features

| Feature | Description |
|---|---|
| **Prompt Management** | Create, edit, and version prompts with variable support (`{{topic}}`) |
| **Provider Management** | Configure OpenAI, Anthropic, and Ollama with custom model settings |
| **Evaluation Suites** | Build test suites with typed assertions to validate prompt behavior |
| **Run Comparison** | Execute prompts across providers and compare results side-by-side |
| **Real-time Dashboard** | Monitor pass rates, costs, and latency metrics live |

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

**1.** Go to **Prompts → New Prompt** and write a prompt with variables, e.g.:

```
Explain {{topic}} in exactly 3 sentences.
```

**2.** Go to **Suites → New Suite**, add test cases with variable values and assertions.

**3.** Run the suite and compare results across providers side-by-side.

**4.** Monitor the **Dashboard** to track pass rates, costs, and metrics over time.

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
