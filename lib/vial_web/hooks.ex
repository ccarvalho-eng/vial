defmodule VialWeb.Hooks do
  @moduledoc """
  LiveView hooks for common functionality across all LiveViews.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  @doc """
  Sets the current path in assigns for active navigation link detection.
  """
  def on_mount(:set_current_path, _params, _session, socket) do
    {:cont, attach_hook(socket, :set_current_path, :handle_params, &set_current_path/3)}
  end

  defp set_current_path(_params, uri, socket) do
    {:cont, assign(socket, :current_path, URI.parse(uri).path)}
  end
end
