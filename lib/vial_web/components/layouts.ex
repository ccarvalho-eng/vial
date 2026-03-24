defmodule VialWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use VialWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string, default: "", doc: "the current path for active link detection"
  attr :base_path, :string, default: "", doc: "the base path for embedded mode"

  slot :inner_block, required: true

  def app(assigns) do
    # Ensure base_path is set
    assigns = assign_new(assigns, :base_path, fn -> "" end)

    ~H"""
    <header class="vial-header">
      <div class="vial-header-inner">
        <nav class="vial-nav">
          <.nav_link href={@base_path <> "/"} current_path={@current_path} base_path={@base_path}>
            <div style="display: flex; align-items: center; gap: 6px;">
              <.icon name="hero-beaker" class="size-4" />
              <span>Vial</span>
            </div>
          </.nav_link>
          <.nav_link
            href={@base_path <> "/prompts"}
            current_path={@current_path}
            base_path={@base_path}
          >
            Prompts
          </.nav_link>
          <.nav_link
            href={@base_path <> "/suites"}
            current_path={@current_path}
            base_path={@base_path}
          >
            Suites
          </.nav_link>
          <.nav_link
            href={@base_path <> "/providers"}
            current_path={@current_path}
            base_path={@base_path}
          >
            Providers
          </.nav_link>
        </nav>
        <div style="margin-left: auto;">
          <.theme_toggle />
        </div>
      </div>
    </header>

    <main class="vial-main">
      <div class="vial-container">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  # Renders a navigation link with active state detection
  attr :href, :string, required: true
  attr :current_path, :string, default: ""
  attr :base_path, :string, default: ""
  slot :inner_block, required: true

  defp nav_link(assigns) do
    # For active state detection, we need to handle the base path correctly
    base_path = assigns.base_path || ""

    # Only try to replace if base_path is not empty
    href_path =
      if base_path != "" do
        String.replace_leading(assigns.href, base_path, "")
      else
        assigns.href
      end

    current_path =
      if base_path != "" do
        String.replace_leading(assigns.current_path, base_path, "")
      else
        assigns.current_path
      end

    active =
      if current_path == href_path or
           (href_path != "/" and String.starts_with?(current_path, href_path <> "/")) do
        "active"
      else
        ""
      end

    assigns = assign(assigns, :active, active)

    ~H"""
    <.link navigate={@href} class={"vial-nav-link #{@active}"}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      class="theme-toggle"
      style="display: flex; gap: 4px; background-color: var(--bg-tertiary); border-radius: 8px; padding: 4px;"
    >
      <button
        class="theme-toggle-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System"
        style="padding: 6px 8px; border-radius: 6px; border: none; background: none; cursor: pointer; color: var(--text-secondary); transition: all 0.2s;"
      >
        <.icon name="hero-computer-desktop" class="size-4" />
      </button>

      <button
        class="theme-toggle-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light"
        style="padding: 6px 8px; border-radius: 6px; border: none; background: none; cursor: pointer; color: var(--text-secondary); transition: all 0.2s;"
      >
        <.icon name="hero-sun" class="size-4" />
      </button>

      <button
        class="theme-toggle-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark"
        style="padding: 6px 8px; border-radius: 6px; border: none; background: none; cursor: pointer; color: var(--text-secondary); transition: all 0.2s;"
      >
        <.icon name="hero-moon" class="size-4" />
      </button>
    </div>
    """
  end
end
