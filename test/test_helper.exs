# Exclude integration tests that require external services or real API keys
# Run with: mix test --include ollama (if you have Ollama running)
# Run with: mix test --include anthropic_integration (requires ANTHROPIC_API_KEY)
# Run with: mix test --include openai_integration (requires OPENAI_API_KEY)
ExUnit.start(exclude: [:ollama, :anthropic_integration, :openai_integration])
