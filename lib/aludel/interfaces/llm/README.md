# LLM Interfaces

Clean adapter pattern separating HTTP transport from provider logic.

## Structure

```
lib/aludel/interfaces/
├── adapters/http.ex           # Generic HTTP behaviour
├── llm.ex                      # LLM client (public API)
└── llm/
    ├── adapters/http/
    │   └── default.ex          # ReqLLM + telemetry
    ├── providers/
    │   ├── openai.ex
    │   ├── anthropic.ex
    │   └── ollama.ex
    ├── behaviour.ex            # Provider contract
    ├── config.ex               # HTTP adapter + API key utils
    └── error_parser.ex
```

**Layers:**
- **HTTP** (`adapters/http/`): Transport, normalization, telemetry
- **Providers** (`llm/providers/`): Auth, validation
- **Utilities** (`config.ex`, `error_parser.ex`): Shared helpers

## Configuration

```elixir
# config/config.exs
config :aludel,
  http_client: Aludel.Interfaces.LLM.Adapters.Http.Default

# config/test.exs
config :aludel,
  http_client: Aludel.Interfaces.HttpClientMock
```

## Adding a Provider

Create `lib/aludel/interfaces/llm/providers/gemini.ex`:

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

Register in `lib/aludel/interfaces/llm.ex`:

```elixir
@providers %{
  openai: OpenAI,
  anthropic: Anthropic,
  ollama: Ollama,
  gemini: Gemini
}
```

## Swapping HTTP Client

Create adapter implementing `Aludel.Interfaces.Adapters.Http`:

```elixir
defmodule Aludel.Interfaces.LLM.Adapters.Http.HTTPoison do
  @behaviour Aludel.Interfaces.Adapters.Http

  @impl true
  def request(model_spec, prompt, opts) do
    # HTTP call, normalize response
    {:ok, %{content: "...", input_tokens: 0, output_tokens: 0}}
  end
end
```

Update config:

```elixir
config :aludel, http_client: Aludel.Interfaces.LLM.Adapters.Http.HTTPoison
```

## Telemetry Events

- `[:aludel, :llm, :http, :start]` - Request begins
- `[:aludel, :llm, :http, :stop]` - Request succeeds (includes tokens)
- `[:aludel, :llm, :http, :exception]` - Request fails

Example handler:

```elixir
:telemetry.attach_many("aludel-llm", [
  [:aludel, :llm, :http, :stop]
], fn [:aludel, :llm, :http, :stop], measurements, metadata, _ ->
  Logger.info("LLM call: #{metadata.model_spec}, tokens: #{measurements.input_tokens + measurements.output_tokens}")
end, nil)
```

## Design Principles

- Generic HTTP behaviour (not LLM-specific)
- No type leakage (providers never see library types)
- Dependency injection via config
- Mock at HTTP layer for tests
- Telemetry for observability
