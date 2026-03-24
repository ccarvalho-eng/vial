defmodule VialWeb.Router do
  @moduledoc """
  Route generation support for Vial LiveViews.

  This module exists solely to support verified routes in LiveViews
  when Vial is used as an embedded library. It doesn't define actual
  routes - those are created by the host application via Vial.Router.

  The actual routing is handled by the host application's router when
  it mounts Vial using the vial_dashboard/2 macro.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: VialWeb.Endpoint,
    router: __MODULE__,
    statics: ~w(assets fonts images favicon.ico robots.txt)

  # This is a placeholder function required by Phoenix.VerifiedRoutes
  # The actual route verification happens in the host app's router
  def __routes__, do: []

  # Support verified routes - in embedded mode, we treat all routes as verified
  # since the actual routing is handled by the host application
  def verified_route?(_, _), do: true
end
