defmodule Vial.Web.RouterTest do
  use ExUnit.Case, async: true

  defmodule TestRouter do
    use Phoenix.Router
    import Vial.Web.Router

    scope "/" do
      vial_dashboard("/vial")
    end
  end

  test "vial_dashboard macro generates routes" do
    routes = TestRouter.__routes__()

    # Dashboard route
    assert Enum.any?(routes, fn route ->
             route.path == "/vial" &&
               get_in(route.metadata, [:phoenix_live_view]) |> elem(0) == Vial.Web.DashboardLive
           end)

    # Asset routes
    assert Enum.any?(routes, fn route ->
             String.starts_with?(route.path, "/vial/css-")
           end)

    # Prompts route
    assert Enum.any?(routes, fn route ->
             route.path == "/vial/prompts" &&
               get_in(route.metadata, [:phoenix_live_view]) |> elem(0) ==
                 Vial.Web.PromptLive.Index
           end)
  end
end
