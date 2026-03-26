defmodule Vial.Web.Router do
  @moduledoc """
  Provides the vial_dashboard macro for mounting Vial in host apps.
  """

  @default_opts [
    resolver: Vial.Web.Resolver,
    socket_path: "/live"
  ]

  @doc """
  Defines a vial dashboard route.

  ## Options

  * `:as` - override route name (default: :vial_dashboard)
  * `:csp_nonce_assign_key` - CSP nonce keys (nil, atom, or map)
  * `:logo_path` - custom logo link path
  * `:on_mount` - additional mount hooks
  * `:vial_name` - Vial instance name (default: Vial)
  * `:resolver` - Vial.Web.Resolver implementation
  * `:socket_path` - phoenix socket path (default: "/live")

  ## Examples

      scope "/" do
        pipe_through :browser
        vial_dashboard "/vial"
      end
  """
  defmacro vial_dashboard(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote bind_quoted: binding() do
      prefix = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} =
          Vial.Web.Router.__options__(prefix, opts)

        live_session session_name, session_opts do
          get "/css-:md5", Vial.Web.Assets, :css, as: :vial_web_asset
          get "/js-:md5", Vial.Web.Assets, :js, as: :vial_web_asset
          get "/fonts/*path", Vial.Web.Assets, :font, as: :vial_web_font
          get "/icons/*path", Vial.Web.Assets, :icon, as: :vial_web_icon

          live "/", Vial.Web.DashboardLive, :index, route_opts

          live "/prompts", Vial.Web.PromptLive.Index, :index, route_opts
          live "/prompts/new", Vial.Web.PromptLive.New, :new, route_opts
          live "/prompts/:id/edit", Vial.Web.PromptLive.New, :edit, route_opts
          live "/prompts/:id/evolution", Vial.Web.PromptLive.Evolution, :show, route_opts
          live "/prompts/:id", Vial.Web.PromptLive.Show, :show, route_opts

          live "/runs/new", Vial.Web.RunLive.New, :new, route_opts
          live "/runs/:id", Vial.Web.RunLive.Show, :show, route_opts

          live "/suites", Vial.Web.SuiteLive.Index, :index, route_opts
          live "/suites/new", Vial.Web.SuiteLive.New, :new, route_opts
          live "/suites/:id/edit", Vial.Web.SuiteLive.New, :edit, route_opts
          live "/suites/:id", Vial.Web.SuiteLive.Show, :show, route_opts

          live "/providers", Vial.Web.ProviderLive.Index, :index, route_opts
          live "/providers/new", Vial.Web.ProviderLive.New, :new, route_opts
          live "/providers/:id/edit", Vial.Web.ProviderLive.New, :edit, route_opts
        end
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias_ast, env) do
    Macro.expand(alias_ast, %{env | function: {:vial_dashboard, 2}})
  end

  defp expand_alias(other, _env), do: other

  @doc false
  def __options__(prefix, opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    on_mount = List.wrap(Keyword.get(opts, :on_mount, [])) ++ [Vial.Web.Authentication]

    session_args = [
      prefix,
      opts[:vial_name],
      opts[:resolver],
      opts[:socket_path],
      opts[:csp_nonce_assign_key],
      opts[:logo_path]
    ]

    session_opts = [
      on_mount: on_mount,
      session: {__MODULE__, :__session__, session_args},
      root_layout: {Vial.Web.Layouts, :root}
    ]

    session_name = Keyword.get(opts, :as, :vial_dashboard)

    {session_name, session_opts, as: session_name}
  end

  @doc false
  def __session__(
        conn,
        prefix,
        vial_name,
        resolver,
        live_path,
        csp_key,
        logo_path
      ) do
    user = Vial.Web.Resolver.call_with_fallback(resolver, :resolve_user, [conn])
    csp_keys = expand_csp_nonce_keys(csp_key)

    %{
      "prefix" => prefix,
      "vial_name" => vial_name,
      "user" => user,
      "resolver" => resolver,
      "access" => Vial.Web.Resolver.call_with_fallback(resolver, :resolve_access, [user]),
      "refresh" => Vial.Web.Resolver.call_with_fallback(resolver, :resolve_refresh, [user]),
      "live_path" => live_path,
      "logo_path" => logo_path,
      "csp_nonces" => %{
        img: conn.assigns[csp_keys[:img]],
        style: conn.assigns[csp_keys[:style]],
        script: conn.assigns[csp_keys[:script]]
      }
    }
  end

  defp expand_csp_nonce_keys(nil), do: %{img: nil, style: nil, script: nil}
  defp expand_csp_nonce_keys(key) when is_atom(key), do: %{img: key, style: key, script: key}
  defp expand_csp_nonce_keys(map) when is_map(map), do: map

  defp validate_opt!({:socket_path, path}) do
    unless is_binary(path) and byte_size(path) > 0 do
      raise ArgumentError, """
      invalid :socket_path, expected a binary URL, got: #{inspect(path)}
      """
    end
  end

  defp validate_opt!({:resolver, resolver}) do
    unless is_atom(resolver) and not is_nil(resolver) do
      raise ArgumentError, """
      invalid :resolver, expected a module implementing Vial.Web.Resolver,
      got: #{inspect(resolver)}
      """
    end
  end

  defp validate_opt!({:vial_name, name}) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :vial_name, expected a module or atom,
      got #{inspect(name)}
      """
    end
  end

  defp validate_opt!({:logo_path, path}) do
    unless is_nil(path) or (is_binary(path) and byte_size(path) > 0) do
      raise ArgumentError, """
      invalid :logo_path, expected nil or a non-empty binary path,
      got: #{inspect(path)}
      """
    end
  end

  defp validate_opt!({:csp_nonce_assign_key, key}) do
    unless is_nil(key) or is_atom(key) or is_map(key) do
      raise ArgumentError, """
      invalid :csp_nonce_assign_key, expected nil, atom, or map with
      atom keys, got #{inspect(key)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
