# Vial

**LLM prompt evaluation workbench**

[![Elixir](https://img.shields.io/badge/Elixir-1.16-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.7-orange?logo=phoenix-framework&logoColor=white)](https://phoenixframework.org)
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

## Setup

**1. Clone and install dependencies**

```bash
git clone https://github.com/yourusername/vial.git
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

## License

Licensed under the [Apache License 2.0](LICENSE).
