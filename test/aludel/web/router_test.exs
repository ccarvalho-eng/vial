defmodule Aludel.Web.RouterTest do
  use ExUnit.Case, async: true

  defmodule TestRouter do
    use Phoenix.Router
    import Aludel.Web.Router

    scope "/" do
      aludel_dashboard("/aludel")
    end
  end

  test "aludel_dashboard macro generates routes" do
    routes = TestRouter.__routes__()

    # Dashboard route
    assert Enum.any?(routes, fn route ->
             route.path == "/aludel" &&
               get_in(route.metadata, [:phoenix_live_view]) |> elem(0) == Aludel.Web.DashboardLive
           end)

    # Asset routes
    assert Enum.any?(routes, fn route ->
             String.starts_with?(route.path, "/aludel/css-")
           end)

    # Prompts route
    assert Enum.any?(routes, fn route ->
             route.path == "/aludel/prompts" &&
               get_in(route.metadata, [:phoenix_live_view]) |> elem(0) ==
                 Aludel.Web.PromptLive.Index
           end)
  end
end
