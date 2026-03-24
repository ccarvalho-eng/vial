defmodule Vial.Web.AuthenticationTest do
  use ExUnit.Case, async: true

  alias Vial.Web.Authentication

  describe "on_mount/4" do
    test "assigns access and refresh from session" do
      session = %{
        "access" => :read_only,
        "refresh" => 10,
        "user" => %{id: 1}
      }

      socket = %Phoenix.LiveView.Socket{
        private: %{connect_params: %{}, connect_info: %{session: session}}
      }

      {:cont, updated_socket} = Authentication.on_mount(:default, %{}, session, socket)

      assert updated_socket.assigns.access == :read_only
      assert updated_socket.assigns.refresh == 10
      assert updated_socket.assigns.user == %{id: 1}
    end
  end
end
