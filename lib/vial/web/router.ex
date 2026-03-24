defmodule Vial.Web.Router do
  @moduledoc """
  Provides the `vial_dashboard/2` macro for embedding Vial in Phoenix routers.

  ## Example

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Vial.Web.Router

        scope "/" do
          pipe_through :browser
          vial_dashboard("/vial")
        end
      end
  """

  @default_opts [
    resolver: Vial.Web.Resolver,
    socket_path: "/live",
    transport: "websocket"
  ]

  @doc """
  Mounts the Vial dashboard at the given path.

  ## Options

    * `:resolver` - Module implementing access control resolution
      (default: `Vial.Web.Resolver`)
    * `:name` - Dashboard instance name (default: `:vial`)
    * `:socket_path` - Phoenix LiveView socket path
      (default: `"/live"`)
    * `:transport` - WebSocket transport protocol
      (default: `"websocket"`)
    * `:authentication` - Access control rules - can be:
      * `false` - Disables authentication (open access)
      * `{:bearer, secret}` - Bearer token authentication
      * `{:basic, [username: "...", password: "..."]}` - HTTP Basic auth

  ## Examples

      # Default configuration
      vial_dashboard("/vial")

      # Custom configuration
      vial_dashboard("/admin/vial",
        name: :admin_vial,
        authentication: {:basic, username: "admin", password: "secret"}
      )

      # Disable authentication (NOT recommended for production)
      vial_dashboard("/vial", authentication: false)
  """
  defmacro vial_dashboard(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        {name, live_opts} = Vial.Web.Router.__options__(path, opts)

        live_session name, session: {Vial.Web.Router, :__session__, [name, live_opts]} do
          live("/", Vial.Web.DashboardLive, :home)
        end

        scope "/assets" do
          get("/css/:asset", Vial.Web.Assets, :css)
          get("/js/:asset", Vial.Web.Assets, :js)
          get("/fonts/:asset", Vial.Web.Assets, :fonts)
          get("/icons/:asset", Vial.Web.Assets, :icons)
        end
      end
    end
  end

  @doc false
  def __options__(path, opts) do
    opts = Keyword.merge(@default_opts, opts)
    name = Keyword.get(opts, :name, :vial)

    cond do
      !is_binary(path) ->
        raise ArgumentError, "path must be a string, got: #{inspect(path)}"

      !is_atom(name) ->
        raise ArgumentError, "name must be an atom, got: #{inspect(name)}"

      !valid_resolver?(opts[:resolver]) ->
        raise ArgumentError,
              "resolver must be a module, got: #{inspect(opts[:resolver])}"

      !valid_socket_path?(opts[:socket_path]) ->
        raise ArgumentError,
              "socket_path must be a string, got: #{inspect(opts[:socket_path])}"

      !valid_transport?(opts[:transport]) ->
        raise ArgumentError,
              "transport must be 'websocket' or 'longpoll', " <>
                "got: #{inspect(opts[:transport])}"

      !valid_authentication?(opts[:authentication]) ->
        raise ArgumentError,
              "authentication must be false, {:bearer, secret}, or " <>
                "{:basic, [username: ..., password: ...]}, " <>
                "got: #{inspect(opts[:authentication])}"

      true ->
        {name, opts}
    end
  end

  defp valid_resolver?(resolver) do
    is_atom(resolver) and resolver != nil
  end

  defp valid_socket_path?(path) do
    is_binary(path) and String.starts_with?(path, "/")
  end

  defp valid_transport?(transport) when transport in ["websocket", "longpoll"], do: true
  defp valid_transport?(_), do: false

  defp valid_authentication?(false), do: true
  defp valid_authentication?({:bearer, secret}) when is_binary(secret), do: true

  defp valid_authentication?({:basic, credentials}) when is_list(credentials) do
    Keyword.has_key?(credentials, :username) and
      Keyword.has_key?(credentials, :password) and
      is_binary(credentials[:username]) and
      is_binary(credentials[:password])
  end

  defp valid_authentication?(nil), do: true
  defp valid_authentication?(_), do: false

  @doc false
  def __session__(
        _conn,
        name,
        resolver,
        socket_path,
        transport,
        authentication,
        _extra1,
        _extra2
      ) do
    %{
      "vial_name" => name,
      "resolver" => resolver,
      "socket_path" => socket_path,
      "transport" => transport,
      "authentication" => authentication
    }
  end
end
