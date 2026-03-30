# LLM Interfaces Architecture

This directory contains the LLM abstraction layer, providing clean separation between HTTP transport and provider-specific logic.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Aludel.LLM                          │  Public API
│               (calculates cost, latency)                │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │  LLM.Providers (via Config)   │
         │  - OpenAI                     │  Business logic
         │  - Anthropic                  │  (auth, validation)
         │  - Ollama                     │
         └──┬──────────────────────────┬─┘
            │                          │
   ┌────────┴────────┐        ┌────────┴────────────────────┐
   │                 │        │                             │
   ▼                 ▼        ▼                             ▼
┌──────────┐  ┌──────────┐  ┌─────────────────────────────────┐
│  Config  │  │  Error   │  │  Adapters.Http (behaviour)      │
│          │  │  Parser  │  │  ┌───────────────────────────┐  │
│ - http_  │  │          │  │  │ LLM.Adapters.Http.Default │  │  Transport
│   adapter│  │ - parse_ │  │  │ (ReqLLM + telemetry)      │  │  layer
│ - get_   │  │   error  │  │  └───────────────────────────┘  │
│   api_key│  │          │  │  - HTTPoison (swappable)        │
└──────────┘  └──────────┘  │  - Mock (tests)                 │
                            └─────────────────────────────────┘
```

## Configuration

### Development/Production (config/config.exs)

```elixir
config :aludel,
  http_client: Aludel.Interfaces.LLM.Adapters.Http.Default
```

### Testing (config/test.exs)

```elixir
config :aludel,
  # Use mock for all tests
  http_client: Aludel.Interfaces.HttpClientMock
```

## Adding a New HTTP Client

To swap HTTP clients (e.g., use HTTPoison instead of ReqLLM):

1. **Create adapter** implementing `Aludel.Interfaces.Adapters.Http`:

```elixir
defmodule Aludel.Interfaces.LLM.Adapters.Http.HTTPoison do
  @behaviour Aludel.Interfaces.Adapters.Http

  @impl true
  def request(model_spec, prompt, opts) do
    # Parse model_spec and make HTTP request
    # Return normalized response for LLMs
    {:ok, %{
      content: "...",
      input_tokens: 0,
      output_tokens: 0
    }}
  end
end
```

2. **Update config**:

```elixir
config :aludel,
  http_client: Aludel.Interfaces.LLM.Adapters.Http.HTTPoison
```

3. **Done!** Providers unchanged, tests unchanged.

## Adding a New Provider

To add a new LLM provider (e.g., Google Gemini):

1. **Create implementation** in `lib/aludel/interfaces/llm/providers/gemini.ex`:

```elixir
defmodule Aludel.Interfaces.LLM.Providers.Gemini do
  alias Aludel.Interfaces.LLM.{Config, ErrorParser}

  @behaviour Aludel.Interfaces.LLM.Behaviour

  @impl true
  def generate(model, prompt, config, _opts) do
    with {:ok, api_key} <- Config.get_api_key(config) do
      opts = [api_key: api_key, temperature: config["temperature"] || 0.7]

      case Config.http_adapter().request("gemini:#{model}", prompt, opts) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> ErrorParser.parse_error(reason)
      end
    end
  end
end
```

2. **Register in main LLM module** (`lib/aludel/llm.ex`):

```elixir
defp get_adapter(:gemini), do: Aludel.Interfaces.LLM.Providers.Gemini
```

## Key Design Principles

### 1. **Generic HTTP Adapter**

- `Adapters.Http` is truly generic - not tied to LLMs
- Domain-specific implementations (LLM, webhooks, etc.) live in their own namespaces
- Single behaviour, multiple use cases

### 2. **Separation of Concerns**

- **HTTP Layer** (`llm/adapters/http/`): Transport + normalization + telemetry
- **Provider Layer** (`llm/*.ex`): Business logic (auth, validation)
- **Shared Utilities** (`llm/config.ex`, `llm/error_parser.ex`): DRY helpers

### 3. **No Type Leakage**

- HTTP implementations return generic terms (`{:ok, term()}`)
- LLM HTTP adapter normalizes to `%{content, input_tokens, output_tokens}`
- Providers never see library-specific types

### 4. **Dependency Injection**

- HTTP adapter via `Config.http_adapter/0`
- Mockable for testing
- Configurable per environment

### 5. **Observability via Telemetry**

- HTTP adapter emits telemetry for all LLM requests
- Track duration, token usage, errors
- Events: `[:aludel, :llm, :http, :start | :stop | :exception]`

### 6. **Always Mock in Tests**

- No real API calls
- Fast, reliable, offline tests
- Mock implements generic `Http` behaviour

## Folder Structure

```
lib/aludel/interfaces/
├── adapters/
│   └── http.ex             # Generic HTTP behaviour
│
└── llm/
    ├── adapters/http/
    │   └── default.ex      # Default HTTP client (ReqLLM + telemetry)
    │
    ├── providers/
    │   ├── openai.ex       # OpenAI provider
    │   ├── anthropic.ex    # Anthropic provider
    │   └── ollama.ex       # Ollama provider
    │
    ├── behaviour.ex        # LLM provider behaviour
    ├── config.ex           # Config utilities (http_adapter, get_api_key)
    └── error_parser.ex     # Shared error parsing
```

## Testing

### Unit Tests (test/aludel/llm_test.exs)

```elixir
test "calls OpenAI provider" do
  mock_response = %{
    content: "Hello!",
    input_tokens: 5,
    output_tokens: 2
  }

  expect(Aludel.Interfaces.HttpClientMock, :generate_text,
    fn _model, _prompt, _opts ->
      {:ok, mock_response}
    end)

  provider = provider_fixture(provider: :openai)
  assert {:ok, result} = LLM.call(provider, "Say hello")
  assert result.output == "Hello!"
end
```

### Integration Tests (optional, tagged)

```elixir
@tag :openai_integration
test "real OpenAI API call" do
  # Configure real HTTP client for this test
  # Requires API key in environment
end
```

Run integration tests: `mix test --include openai_integration`

## Telemetry Integration

The HTTP adapter emits telemetry events for observability. Attach handlers to
monitor performance, track costs, or debug issues.

### Available Events

1. **`[:aludel, :llm, :http, :start]`** - Request begins
   - Measurements: `%{system_time: integer()}`
   - Metadata: `%{model_spec: String.t()}`

2. **`[:aludel, :llm, :http, :stop]`** - Request succeeds
   - Measurements: `%{duration: integer(), input_tokens: integer(),
     output_tokens: integer()}`
   - Metadata: `%{model_spec: String.t()}`

3. **`[:aludel, :llm, :http, :exception]`** - Request fails
   - Measurements: `%{duration: integer()}`
   - Metadata: `%{model_spec: String.t(), error: term()}`

### Example: Logging Handler

```elixir
:telemetry.attach_many(
  "aludel-llm-logger",
  [
    [:aludel, :llm, :http, :start],
    [:aludel, :llm, :http, :stop],
    [:aludel, :llm, :http, :exception]
  ],
  &handle_event/4,
  nil
)

def handle_event([:aludel, :llm, :http, :stop], measurements, metadata, _) do
  Logger.info("LLM request completed",
    model: metadata.model_spec,
    duration_ms: System.convert_time_unit(measurements.duration,
      :native, :millisecond),
    tokens: measurements.input_tokens + measurements.output_tokens
  )
end

def handle_event([:aludel, :llm, :http, :exception], measurements, metadata, _) do
  Logger.error("LLM request failed",
    model: metadata.model_spec,
    duration_ms: System.convert_time_unit(measurements.duration,
      :native, :millisecond),
    error: inspect(metadata.error)
  )
end

def handle_event(_, _, _, _), do: :ok
```

### Example: Metrics Collection

```elixir
def handle_event([:aludel, :llm, :http, :stop], measurements, metadata, _) do
  :telemetry.execute(
    [:my_app, :llm, :tokens],
    %{count: measurements.input_tokens + measurements.output_tokens},
    %{provider: extract_provider(metadata.model_spec)}
  )
end

defp extract_provider("openai:" <> _), do: "openai"
defp extract_provider("anthropic:" <> _), do: "anthropic"
defp extract_provider(_), do: "unknown"
```

## Benefits

- Easy to swap HTTP clients via config
- Clean boundaries with no type leakage
- Testable with mocks at HTTP layer
- Each layer has one responsibility
- Add new providers without touching HTTP code
