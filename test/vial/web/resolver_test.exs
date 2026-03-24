defmodule Vial.Web.ResolverTest do
  use ExUnit.Case, async: true

  alias Vial.Web.Resolver

  defmodule TestResolver do
    @behaviour Vial.Web.Resolver

    @impl true
    def resolve_user(_conn), do: %{id: 1, name: "Test User"}

    @impl true
    def resolve_access(_user), do: :read_only

    @impl true
    def resolve_refresh(_user), do: 10
  end

  describe "call_with_fallback/3" do
    test "calls custom resolver implementation" do
      conn = %Plug.Conn{}

      assert Resolver.call_with_fallback(TestResolver, :resolve_user, [conn]) ==
               %{id: 1, name: "Test User"}
    end

    test "falls back to default implementation" do
      conn = %Plug.Conn{}
      assert Resolver.call_with_fallback(Resolver, :resolve_user, [conn]) == nil
    end
  end
end
