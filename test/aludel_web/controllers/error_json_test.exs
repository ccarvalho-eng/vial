defmodule Aludel.Web.ErrorJSONTest do
  use Aludel.Web.ConnCase, async: true

  test "renders 404" do
    assert Aludel.Web.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert Aludel.Web.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
