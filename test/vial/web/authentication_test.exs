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

    test "assigns all session values to socket" do
      session = %{
        "access" => :all,
        "refresh" => 5,
        "user" => %{id: 2, name: "Admin"},
        "resolver" => MyApp.Resolver,
        "vial_name" => :vial,
        "prefix" => "/admin",
        "logo_path" => "/logo.png",
        "csp_nonces" => %{img: "abc", style: "def", script: "ghi"}
      }

      socket = %Phoenix.LiveView.Socket{
        private: %{connect_params: %{}, connect_info: %{session: session}}
      }

      {:cont, updated_socket} = Authentication.on_mount(:default, %{}, session, socket)

      assert updated_socket.assigns.access == :all
      assert updated_socket.assigns.refresh == 5
      assert updated_socket.assigns.user == %{id: 2, name: "Admin"}
      assert updated_socket.assigns.resolver == MyApp.Resolver
      assert updated_socket.assigns.vial_name == :vial
      assert updated_socket.assigns.prefix == "/admin"
      assert updated_socket.assigns.logo_path == "/logo.png"
      assert updated_socket.assigns.csp_nonces == %{img: "abc", style: "def", script: "ghi"}
    end
  end
end
