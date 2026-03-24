defmodule VialWeb.PathHelpers do
  @moduledoc """
  Path helpers for generating URLs in embedded mode.

  Since Vial can be mounted at any path, we need to generate
  paths that include the base path from the configuration.
  """

  @doc """
  Generates a path with the base path prepended.

  Returns a URI struct that LiveView can properly resolve.

  Examples:
      vial_path(@socket, "/prompts")
      vial_path(@socket, "/prompts/\#{id}")
  """
  def vial_path(socket_or_assigns, path) when is_binary(path) do
    base_path = get_base_path(socket_or_assigns)
    base_path <> path
  end

  defp get_base_path(%Phoenix.LiveView.Socket{assigns: assigns}) do
    Map.get(assigns, :base_path, "")
  end

  defp get_base_path(%{} = assigns) do
    Map.get(assigns, :base_path, "")
  end
end
