defmodule Aludel.Web.SuiteLive.Index do
  @moduledoc """
  LiveView for listing evaluation suites.

  Displays all suites with their associated prompt names.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    suites = Evals.list_suites_with_prompt()

    socket =
      socket
      |> assign(:page_title, "Suites")
      |> assign(:suites, suites)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    suite = Evals.get_suite!(id)
    {:ok, _} = Evals.delete_suite(suite)

    {:noreply,
     socket
     |> assign(:suites, Evals.list_suites_with_prompt())
     |> put_flash(:info, "Suite deleted successfully")}
  end
end
