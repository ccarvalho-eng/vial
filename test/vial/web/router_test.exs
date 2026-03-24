defmodule Vial.Web.RouterTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  defmodule TestRouter do
    use Phoenix.Router
    import Vial.Web.Router

    scope "/" do
      vial_dashboard("/vial")
    end
  end

  test "vial_dashboard macro generates routes" do
    assert TestRouter.__routes__()
           |> Enum.any?(fn route ->
             route.path == "/vial" && route.plug == Vial.Web.DashboardLive
           end)
  end
end
