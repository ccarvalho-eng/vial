defmodule Aludel.Web do
  @moduledoc false

  def html do
    quote do
      @moduledoc false

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      @moduledoc false

      use Phoenix.LiveView

      on_mount {Aludel.Web.Hooks, :set_current_path}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      @moduledoc false

      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      import Aludel.Web.CoreComponents
      import Aludel.Web.Helpers

      alias Aludel.Web.Layouts
      alias Phoenix.LiveView.JS
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
