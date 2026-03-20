# Exclude integration tests that require external services (like Ollama)
# Run with: mix test --include ollama (if you have Ollama running)
ExUnit.start(exclude: [:ollama])
Ecto.Adapters.SQL.Sandbox.mode(Vial.Repo, :manual)
