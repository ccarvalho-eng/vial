defmodule Aludel.Web.Resolver do
  @moduledoc """
  Behavior for customizing dashboard access and user identification.

  Host applications can implement this behavior to control who can access
  the dashboard, identify users, and customize refresh rates.

  ## Example

      defmodule MyApp.AludelResolver do
        @behaviour Aludel.Web.Resolver

        @impl true
        def resolve_user(conn) do
          conn.assigns[:current_user]
        end

        @impl true
        def resolve_access(user) do
          if user && user.role == :admin, do: :all, else: :read_only
        end

        @impl true
        def resolve_refresh(_user) do
          15
        end
      end

  Then configure it in your router:

      use Aludel.Web, :router,
        resolver: MyApp.AludelResolver

  ## Default Behavior

  If no custom resolver is configured, the defaults are:
  - `resolve_user/1` returns `nil`
  - `resolve_access/1` returns `:all`
  - `resolve_refresh/1` returns `5`
  """

  @doc """
  Resolves the current user from the connection.

  Return `nil` if no user is authenticated.
  """
  @callback resolve_user(conn :: Plug.Conn.t()) :: term()

  @doc """
  Resolves the access level for a user.

  Return `:all` for full access or `:read_only` for restricted access.
  """
  @callback resolve_access(user :: term()) :: :all | :read_only

  @doc """
  Resolves the refresh interval in seconds for a user.
  """
  @callback resolve_refresh(user :: term()) :: pos_integer()

  @doc """
  Calls a resolver callback with fallback to default implementation.

  If the resolver module implements the callback, it is called with the
  given args. Otherwise, the default implementation is used.
  """
  @spec call_with_fallback(module(), atom(), list()) :: term()
  def call_with_fallback(resolver, callback, args) do
    if function_exported?(resolver, callback, length(args)) do
      apply(resolver, callback, args)
    else
      apply(__MODULE__, callback, args)
    end
  end

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_refresh(_user), do: 5
end
