defmodule VialWeb.PageController do
  use VialWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
