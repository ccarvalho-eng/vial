defmodule Vial.Hooks do
  @moduledoc """
  LiveView hooks for configuration injection in embedded mode.
  """

  import Phoenix.Component

  @doc """
  Injects Vial configuration into the socket assigns.

  This hook is automatically mounted by the vial_dashboard macro
  and provides the repo and other configuration to all LiveViews.
  """
  def on_mount(:inject_config, _params, _session, socket) do
    # Get config from the process dictionary where the macro stored it
    config = Process.get(:vial_config) || []

    socket =
      socket
      |> assign(:vial_repo, config[:repo])
      |> assign(:vial_openai_api_key, resolve_api_key(config[:openai_api_key]))
      |> assign(:vial_prefix, config[:prefix] || "public")
      |> assign(:vial_resolver, config[:resolver])
      |> assign(:vial_csp_nonce, config[:csp_nonce_assign_key])

    {:cont, socket}
  end

  def on_mount(:inject_config, opts, _params, _session, socket) when is_list(opts) do
    # Store config in process dictionary for child LiveViews
    Process.put(:vial_config, opts)

    socket =
      socket
      |> assign(:vial_repo, opts[:repo])
      |> assign(:vial_openai_api_key, resolve_api_key(opts[:openai_api_key]))
      |> assign(:vial_prefix, opts[:prefix] || "public")
      |> assign(:vial_resolver, opts[:resolver])
      |> assign(:vial_csp_nonce, opts[:csp_nonce_assign_key])

    {:cont, socket}
  end

  # Resolve API key from different formats
  defp resolve_api_key(nil), do: nil
  defp resolve_api_key(key) when is_binary(key), do: key

  defp resolve_api_key({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, args)
  end

  defp resolve_api_key(_), do: nil

  @doc """
  Helper to get the configured repo from socket assigns.
  Falls back to Vial.Repo if not in embedded mode.
  """
  def get_repo(socket) do
    socket.assigns[:vial_repo] || Vial.Repo
  end

  @doc """
  Helper to get the OpenAI API key from socket assigns.
  """
  def get_api_key(socket) do
    socket.assigns[:vial_openai_api_key] || System.get_env("OPENAI_API_KEY")
  end

  @doc """
  Helper to get the database prefix from socket assigns.
  """
  def get_prefix(socket) do
    socket.assigns[:vial_prefix] || "public"
  end

  @doc """
  Check if user has permission using the resolver module.
  """
  def can?(socket, action) do
    case socket.assigns[:vial_resolver] do
      nil ->
        # No resolver means full access
        true

      resolver_module ->
        user = socket.assigns[:current_user]

        case action do
          :view -> apply(resolver_module, :can_view_dashboard?, [user])
          :modify_prompts -> apply(resolver_module, :can_modify_prompts?, [user])
          :run_tests -> apply(resolver_module, :can_run_tests?, [user])
          :manage_providers -> apply(resolver_module, :can_manage_providers?, [user])
          _ -> false
        end
    end
  rescue
    # If resolver doesn't implement a method, default to denying access
    _error -> false
  end
end
