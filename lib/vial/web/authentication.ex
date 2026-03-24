defmodule Vial.Web.Authentication do
  @moduledoc """
  LiveView on_mount hook for Vial dashboard authentication.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc false
  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign(:access, session["access"])
      |> assign(:refresh, session["refresh"])
      |> assign(:user, session["user"])
      |> assign(:resolver, session["resolver"])
      |> assign(:vial_name, session["vial_name"])
      |> assign(:prefix, session["prefix"])
      |> assign(:logo_path, session["logo_path"])
      |> assign(:csp_nonces, session["csp_nonces"])

    {:cont, socket}
  end
end
