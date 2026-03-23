# usage-rules.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Project Overview

Vial is an LLM prompt evaluation workbench built with Phoenix LiveView. It enables running prompts across OpenAI, Anthropic, and Ollama simultaneously, comparing output quality, latency, token usage, and cost in real-time.

## Core Commands

### Development

```bash
# Start dev server
mix phx.server

# Run tests (creates/migrates test DB automatically)
mix test

# Run single test file
mix test test/path/to/test.exs

# Run single test by line number
mix test test/path/to/test.exs:42

# Pre-commit checks (format, credo, sobelow, tests)
mix precommit
```

### Database

```bash
# Reset and seed database
mix ecto.reset

# Create and run migrations
mix ecto.create && mix ecto.migrate

# Check migration status
mix ecto.status

# Create new migration
mix ecto.gen.migration migration_name

# Rollback last migration
mix ecto.rollback
```

### Code Quality

```bash
# Format code
mix format

# Lint with Credo (strict mode)
mix credo --strict

# Security checks with Sobelow
mix sobelow --config .sobelow-conf

# Type checking with Dialyzer
mix dialyzer

# Check for unused dependencies
mix deps.unlock --check-unused
```

## Architecture

### Domain Contexts

The app follows Phoenix context patterns with four main domains:

1. **Prompts** (`Vial.Prompts`): Manages prompts and immutable versioning
   - Each edit creates a new `PromptVersion` with auto-incremented version number
   - Variables extracted from `{{variable}}` template syntax
   - Evolution tracking across versions and providers

2. **Providers** (`Vial.Providers`): Multi-LLM provider abstraction
   - Supports OpenAI, Anthropic, and Ollama
   - Provider-specific configuration (temperature, max_tokens, etc.)
   - API keys managed via environment variables

3. **Runs** (`Vial.Runs`): Executes prompts against providers
   - Concurrent execution via `Task.async_stream` (max 3 concurrent)
   - Real-time updates broadcast via Phoenix.PubSub on `"run:#{run_id}"` topic
   - Creates `RunResult` per provider with tokens, latency, cost

4. **Evals** (`Vial.Evals`): Test suites with assertions
   - Test cases with `contains`, `not_contains`, `regex`, `exact_match` assertions
   - Suite execution tracks pass/fail rates, avg cost, avg latency
   - Results stored in `SuiteRun` with per-test-case details

### LLM Integration

`Vial.LLM` provides unified interface across providers:
- Direct HTTP calls via `Req` library
- Structured responses: `%{output, input_tokens, output_tokens, latency_ms, cost_usd}`
- Provider-specific cost calculation (OpenAI: $5/$15 per million, Anthropic: $3/$15, Ollama: free)
- Comprehensive error handling: `:missing_api_key`, `{:auth_error, msg}`, `{:rate_limit, retry_after}`, etc.

### LiveView Architecture

Uses LiveView components with real-time streaming:
- `RunLive.Show`: Subscribes to `Phoenix.PubSub` for live result updates
- `DashboardLive`: Shows cost trends, latency metrics, recent runs
- `PromptLive.Evolution`: Visualizes version performance over time

### Task Supervision

Application starts `Task.Supervisor` named `Vial.TaskSupervisor` for concurrent LLM calls in production. Use this instead of bare `Task.async` for fault tolerance.

## Testing

- Test environment auto-creates and migrates database via `mix test` alias
- Use `test/support/conn_case.ex` for controller tests
- Use `test/support/data_case.ex` for context tests
- Coverage tracked via ExCoveralls

## Configuration

API keys configured via environment variables in `.env`:
- `OPENAI_API_KEY`: OpenAI API key (required for OpenAI providers)
- `ANTHROPIC_API_KEY`: Anthropic API key (required for Anthropic providers)
- Ollama requires no API key (runs locally on port 11434)

## Key Implementation Details

- **Prompt versioning**: Auto-increments on every template edit, maintains full history
- **Variable extraction**: Regex-based `~r/\{\{(\w+)\}\}/` parser finds all `{{var}}` placeholders
- **Concurrent execution**: Limited to 3 concurrent LLM calls via `Task.async_stream` with 120s timeout
- **PubSub broadcasting**: Each run subscribes to `"run:#{run_id}"` topic for real-time result streaming
- **Cost aggregation**: Sums `RunResult.cost_usd` + `SuiteRun.avg_cost_usd` for total spend tracking
- **Assertion evaluation**: Test cases evaluate multiple assertions with AND logic (all must pass)