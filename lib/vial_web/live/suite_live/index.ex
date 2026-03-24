defmodule VialWeb.SuiteLive.Index do
  @moduledoc """
  LiveView for listing evaluation suites.

  Displays all suites with their associated prompt names.
  """

  use VialWeb, :live_view

  alias Vial.Evals
  alias Vial.Hooks

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    repo = Hooks.get_repo(socket)
    suites = Evals.list_suites_with_prompt(repo)

    socket =
      socket
      |> assign(:page_title, "Suites")
      |> assign(:suites, suites)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    repo = Hooks.get_repo(socket)
    suite = Evals.get_suite!(repo, id)
    {:ok, _} = Evals.delete_suite(repo, suite)

    {:noreply,
     socket
     |> assign(:suites, Evals.list_suites_with_prompt(repo))
     |> put_flash(:info, "Suite deleted successfully")}
  end
end
