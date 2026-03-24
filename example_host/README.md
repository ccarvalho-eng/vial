# Example Host Application for Embedded Vial

This directory demonstrates how to use Vial as an embedded library within your Phoenix application.

## Setup Instructions

1. Add Vial to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    # ... your other deps
    {:vial, path: "../"}, # or from hex: {:vial, "~> 0.1.0"}
  ]
end
```

2. Create a migration to set up Vial tables:

```bash
mix ecto.gen.migration add_vial_tables
```

3. Update the migration file:

```elixir
defmodule MyApp.Repo.Migrations.AddVialTables do
  use Ecto.Migration

  def up do
    Vial.Migrations.up()
    # Or with a custom schema:
    # execute "CREATE SCHEMA IF NOT EXISTS vial"
    # Vial.Migrations.up(prefix: "vial")
  end

  def down do
    Vial.Migrations.down()
    # Or with custom schema:
    # Vial.Migrations.down(prefix: "vial")
    # execute "DROP SCHEMA IF EXISTS vial CASCADE"
  end
end
```

4. Run the migration:

```bash
mix ecto.migrate
```

5. Add Vial to your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import Vial.Router

  # ... your pipelines

  pipeline :admin do
    plug :ensure_authenticated
    plug :ensure_admin_role
  end

  scope "/admin" do
    pipe_through [:browser, :admin]

    vial_dashboard "/vial",
      repo: MyApp.Repo,
      openai_api_key: System.get_env("OPENAI_API_KEY")
  end
end
```

## Configuration Options

### Basic Setup

```elixir
vial_dashboard "/vial",
  repo: MyApp.Repo,
  openai_api_key: System.get_env("OPENAI_API_KEY")
```

### With Custom Resolver for Access Control

```elixir
defmodule MyApp.VialResolver do
  use Vial.Resolver

  def can_view_dashboard?(user), do: user.role in [:admin, :developer]
  def can_modify_prompts?(user), do: user.role == :admin
  def can_run_tests?(user), do: true
  def can_manage_providers?(user), do: user.role == :admin
end

# In your router:
vial_dashboard "/vial",
  repo: MyApp.Repo,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  resolver: MyApp.VialResolver
```

### With Custom Database Schema

```elixir
vial_dashboard "/vial",
  repo: MyApp.Repo,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  prefix: "vial"  # Uses PostgreSQL schema "vial" instead of "public"
```

### With LiveView Hooks

```elixir
vial_dashboard "/vial",
  repo: MyApp.Repo,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  on_mount: [{MyApp.Hooks, :verify_admin}]
```

### Dynamic API Key Resolution

```elixir
defmodule MyApp.Config do
  def get_openai_key(user) do
    # Could fetch per-user or per-organization API keys
    user.organization.openai_api_key
  end
end

vial_dashboard "/vial",
  repo: MyApp.Repo,
  openai_api_key: {MyApp.Config, :get_openai_key, []}
```

## Multi-Tenancy Support

For multi-tenant applications, you can use different database schemas:

```elixir
defmodule MyApp.TenantResolver do
  def get_repo_for_tenant(conn) do
    tenant = conn.assigns.current_tenant
    # Return a repo configured for the tenant's schema
    MyApp.Repo.put_dynamic_repo(tenant.schema)
  end
end

vial_dashboard "/vial",
  repo: {MyApp.TenantResolver, :get_repo_for_tenant, []},
  prefix: conn.assigns.current_tenant.schema
```

## Accessing Vial UI

After setup, navigate to:
- `/admin/vial` - Dashboard
- `/admin/vial/prompts` - Manage prompts
- `/admin/vial/providers` - Configure LLM providers
- `/admin/vial/suites` - Test suites
- `/admin/vial/runs` - View test runs

## Troubleshooting

### Tables not found
Ensure migrations ran successfully:
```bash
mix ecto.migrate
```

### Authentication issues
Verify your pipeline includes authentication plugs before mounting Vial.

### Asset loading issues
Vial's assets are pre-compiled and served from `/vial-assets/*`. Ensure your Content Security Policy allows these resources.

### OpenAI API errors
Check that your API key is correctly configured and has sufficient permissions.