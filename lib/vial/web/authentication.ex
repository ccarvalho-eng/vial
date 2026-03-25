defmodule Vial.Web.Authentication do
  @moduledoc """
  LiveView on_mount hook for Vial dashboard authentication.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc false
  def on_mount(:default, _params, session, socket) do
    # Store routing info in process dictionary for vial_path helper
    Process.put(:routing, {socket, session["prefix"]})

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
      |> assign(:live_path, session["live_path"])
      |> assign(:live_transport, session["live_transport"])

    {:cont, socket}
  end
end
