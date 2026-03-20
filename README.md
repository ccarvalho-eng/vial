```
⠀⠀⠀⣠⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠈⠻⠿⠃⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⣀⣀⣀⣀⣀⣀⣉⣁⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠘⡿⠿⠿⠿⠿⠿⠿⢿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⡇⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀ █████   █████  ███            ████
⠀⡇⠀⠀⠀⠀⣀⠀⢸⠀⠀⠀⠀⠀⠀⠀░░███   ░░███  ░░░            ░░███
⠀⣇⣀⣀⣀⣀⣛⣃⣸⠀⠀⠀⠀⠀⠀⠀ ░███    ░███  ████   ██████   ░███
⠀⣿⡿⠿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀ ░███    ░███ ░░███  ░░░░░███  ░███
⠀⣿⣷⣤⣾⠋⠉⢻⣿⠀⠀⠀⠀⠀⠀⠀ ░░███   ███   ░███   ███████  ░███
⠀⣿⣿⣿⣿⣦⣴⣾⣿⠀⠀⠀⠀⠀⠀⠀  ░░░█████░    ░███  ███░░███  ░███
⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀    ░░███      █████░░████████ █████
⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀     ░░░      ░░░░░  ░░░░░░░░ ░░░░░
⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠻⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠈⠙⠛⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
```
LLM prompt evaluation workbench

## Features

- **Prompt Management**: Create, edit, and version your prompts with variable support
- **Provider Management**: Configure multiple LLM providers (OpenAI, Anthropic, Ollama) with custom settings
- **Evaluation Suites**: Build test suites with assertions to validate prompt behavior
- **Run Comparison**: Execute prompts across multiple providers and compare results
- **Real-time Dashboard**: Monitor evaluation metrics, test pass rates, and costs
- **Minimalist UI**: Clean design with refined typography and smooth interactions

## Prerequisites

- Elixir 1.14+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

## Setup

1. **Clone and install dependencies**:
```bash
git clone https://github.com/yourusername/vial.git
cd vial
mix deps.get
```

2. **Set up the database**:
```bash
mix ecto.setup
```

3. **Start the Phoenix server**:
```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000)

## Using Ollama Locally (No API Keys Required)

Vial supports **multiple LLM providers** (OpenAI, Anthropic, Ollama). To get started quickly with **Ollama locally** without needing API keys:

1. **Install Ollama**: Download from [ollama.com](https://ollama.com) and follow the installation instructions for your OS

2. **Start Ollama** (if not running):
```bash
ollama serve
```

3. **Pull a model**:
```bash
ollama pull llama2
```
Other recommended models:
- `ollama pull mistral` - Fast and capable
- `ollama pull llama3` - Latest Llama model
- `ollama pull codellama` - Code-focused model

4. **Verify Ollama is running**:
```bash
curl http://localhost:11434/api/tags
```

5. **Run seeds** (creates default Ollama provider):
```bash
mix run priv/repo/seeds.exs
```

The seeds will create:
- Default Ollama provider (llama2)
- 3 sample prompts (Instruction Following, Context Retention, Safety Refusal)
- 3 evaluation suites with test cases

**That's it!** You can now run prompts and evaluations locally without any API costs.

## Adding Other Providers (Optional)

To compare results with OpenAI or Anthropic:

1. Navigate to **Providers** in the UI
2. Click **New Provider**
3. Configure your provider:
   - **OpenAI**: Requires API key from [platform.openai.com](https://platform.openai.com)
   - **Anthropic**: Requires API key from [console.anthropic.com](https://console.anthropic.com)
4. Set model parameters (temperature, max_tokens, etc.)

Vial will then show side-by-side comparisons across all configured providers.

## Quick Start

1. **Create Prompts**: Write prompts with variables (e.g., `{{topic}}`, `{{context}}`)
2. **Build Suites**: Create test suites with variable values and assertions
3. **Run Evaluations**: Execute prompts across multiple providers and compare results side-by-side
4. **Monitor Dashboard**: Track test pass rates, costs, and metrics over time

### Example Workflow

1. Go to **Prompts** → **New Prompt**
2. Create a prompt: `"Explain {{topic}} in exactly 3 sentences."`
3. Go to **Suites** → **New Suite**
4. Add test cases with different topics and assertions
5. Run the suite and see which providers perform best

