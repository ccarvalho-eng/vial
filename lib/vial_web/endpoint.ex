defmodule VialWeb.Endpoint do
  @moduledoc """
  Minimal endpoint module for route generation in embedded mode.

  This module exists solely to support verified routes in LiveViews
  when Vial is used as an embedded library. The actual endpoint
  functionality is provided by the host application's endpoint.
  """

  # Minimal implementation to satisfy Phoenix.VerifiedRoutes
  def url, do: ""
  def path(path), do: path
  def static_path(path), do: "/vial-assets#{path}"
end
