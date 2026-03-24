# Vial

**Embeddable LLM prompt evaluation dashboard for Phoenix applications**

[![CI](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/ci.yml)
[![Security](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml/badge.svg)](https://github.com/ccarvalho-eng/vial/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/ccarvalho-eng/vial/branch/main/graph/badge.svg)](https://codecov.io/gh/ccarvalho-eng/vial)
[![Hex.pm](https://img.shields.io/hexpm/v/vial.svg)](https://hex.pm/packages/vial)

Vial is an embeddable Phoenix LiveView component that adds LLM prompt testing and evaluation capabilities to your Phoenix application. Run prompts across OpenAI, Anthropic, and Ollama simultaneously, compare outputs, track costs, and build evaluation suites—all from within your existing app.

<img width="1371" height="960" alt="Screenshot 2026-03-22 at 18 45 00" src="https://github.com/user-attachments/assets/7d9c43ba-54be-428b-8e44-1762de57b99f" />

## Features

- **Multi-provider comparison** — Run the same prompt across providers side-by-side
- **Prompt management** — Version-controlled templates with variable interpolation
- **Evolution tracking** — Visualize prompt performance over time
- **Evaluation suites** — Automated test cases with assertions
- **Dashboard** — Live metrics for cost, latency, and provider performance
- **Multi-tenant ready** — Full support for database prefixes and isolated data

## Installation

Add `vial` to your Phoenix application's dependencies:

```elixir
# mix.exs
def deps do
  [
    {:vial, "~> 0.1.0"}
  ]
end
```

## Setup

Add Vial to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:vial, "~> 0.1.0"}
  ]
end
```

### 1. Add TaskSupervisor to your application

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... your existing children ...
      {Task.Supervisor, name: MyApp.TaskSupervisor},  # Add this
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 2. Add Vial.Static plug to your endpoint

```elixir
# lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # Add this before your app's static plug
  plug Vial.Static

  # Your existing static configuration
  plug Plug.Static, at: "/", from: :my_app
  # ...
end
```

### 3. Mount the dashboard

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import Vial.Router

  # ... your existing pipelines ...

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      vial_dashboard "/vial",
        repo: MyApp.Repo,
        task_supervisor: MyApp.TaskSupervisor
    end
  end
end
```

### 4. Run migrations and seed data

```bash
mix vial.install
mix ecto.migrate
mix vial.seed  # Optional: adds example prompts and suites
```

Now visit `/dev/vial` in your browser!

## Production Setup

For production, follow the same setup steps but mount at a secured path with authentication.

### 1. Add TaskSupervisor to your application

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      {Task.Supervisor, name: MyApp.TaskSupervisor},  # Add this
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 2. Run Migrations

Generate and run the migration:

```bash
# Default (uses "public" schema)
mix vial.install
mix ecto.migrate

# With custom schema prefix
mix vial.install --prefix my_schema
mix ecto.migrate
```

### 3. Mount the Dashboard

Add Vial to your router using the `vial_dashboard` macro:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import Vial.Router  # Add this import

  # ... your existing pipelines ...

  scope "/admin", MyAppWeb do
    pipe_through [:browser, :authenticate_admin]

    vial_dashboard "/vial",
      repo: MyApp.Repo,
      task_supervisor: MyApp.TaskSupervisor,
      openai_api_key: {MyApp.Config, :get_openai_key, []},
      resolver: MyAppWeb.VialResolver
  end
end
```

### 4. Configure Assets

Add Vial's assets to your endpoint configuration:

```elixir
# lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # Add this before your app's static plug
  plug Vial.Static

  # Your existing static configuration
  plug Plug.Static,
    at: "/",
    from: :my_app,
    # ...
end
```

## Configuration Options

The `vial_dashboard` macro accepts the following options:

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `:repo` | module | Yes | Your application's Ecto repo module |
| `:task_supervisor` | module | Yes | Task.Supervisor module for async operations |
| `:openai_api_key` | string \| MFA | No | OpenAI API key or MFA tuple to retrieve it |
| `:anthropic_api_key` | string \| MFA | No | Anthropic API key or MFA tuple to retrieve it |
| `:prefix` | string | No | Database prefix for multi-tenant apps (default: "public") |
| `:resolver` | module | No | Module implementing `Vial.Resolver` behaviour for authorization |
| `:csp_nonce_assign_key` | atom | No | Socket assign key containing CSP nonce |

### API Key Configuration

API keys can be provided in three ways:

```elixir
# Direct string
openai_api_key: "sk-..."

# Environment variable (retrieved at runtime)
openai_api_key: System.get_env("OPENAI_API_KEY")

# MFA tuple for dynamic retrieval
openai_api_key: {MyApp.Config, :get_openai_key, []}
```

### Multi-Tenant Support

For multi-tenant applications using database prefixes:

```elixir
vial_dashboard "/vial",
  repo: MyApp.Repo,
  task_supervisor: MyApp.TaskSupervisor,
  prefix: socket.assigns.tenant.schema_prefix,
  openai_api_key: {MyApp.Tenants, :get_api_key, [socket.assigns.tenant]}
```

## Provider Setup

### Ollama (No API Key Required)

1. Install Ollama from [ollama.com](https://ollama.com)
2. Start the server: `ollama serve`
3. Pull a model: `ollama pull llama3`
4. Add an Ollama provider in the Vial dashboard

### OpenAI

1. Get an API key from [platform.openai.com](https://platform.openai.com)
2. Configure it in your router or environment
3. Add an OpenAI provider in the dashboard

### Anthropic

1. Get an API key from [console.anthropic.com](https://console.anthropic.com)
2. Configure it in your router or environment
3. Add an Anthropic provider in the dashboard

## Usage

Once mounted, navigate to `/admin/vial` (or your configured path) to:

1. **Create prompts** with `{{variable}}` placeholders
2. **Run prompts** across multiple providers simultaneously
3. **Build test suites** with assertions
4. **Track performance** over prompt versions
5. **Compare providers** on cost, speed, and quality

## Database Schema

Vial creates the following tables in your database, all prefixed with `vial_`:

- `vial_prompts` - Prompt definitions
- `vial_prompt_versions` - Version history for prompts
- `vial_providers` - LLM provider configurations
- `vial_runs` - Individual prompt executions
- `vial_run_results` - Results from each provider
- `vial_suites` - Evaluation suite definitions
- `vial_suite_runs` - Suite execution history
- `vial_test_cases` - Test cases within suites

## Security Considerations

1. **API Keys**: Never commit API keys. Use environment variables or secure vaults.
2. **Authorization**: Implement the `Vial.Resolver` behaviour to control access.
3. **CSP**: If using Content Security Policy, configure the nonce option.
4. **Database Access**: Vial uses your app's repo with full query access.

## Examples

### Basic Setup

```elixir
# Minimal configuration
vial_dashboard "/vial",
  repo: MyApp.Repo,
  task_supervisor: MyApp.TaskSupervisor

# With authentication
vial_dashboard "/vial",
  repo: MyApp.Repo,
  task_supervisor: MyApp.TaskSupervisor,
  resolver: MyAppWeb.VialResolver
```

### With Full Configuration

```elixir
vial_dashboard "/vial",
  repo: MyApp.Repo,
  task_supervisor: MyApp.TaskSupervisor,
  openai_api_key: {MyApp.Vault, :fetch, ["openai_key"]},
  anthropic_api_key: {MyApp.Vault, :fetch, ["anthropic_key"]},
  resolver: MyAppWeb.VialResolver,
  prefix: "tenant_123",
  csp_nonce_assign_key: :csp_nonce
```

## Migrating from Standalone

If you were using Vial as a standalone application:

1. Add vial as a dependency instead of cloning the repo
2. Move your API keys to your main app's configuration
3. Run the migration to create prefixed tables
4. Mount the dashboard in your router
5. Optionally implement authentication via a resolver

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests with `mix test`
4. Ensure quality with `mix precommit`
5. Submit a pull request

## License

[Apache License 2.0](LICENSE)