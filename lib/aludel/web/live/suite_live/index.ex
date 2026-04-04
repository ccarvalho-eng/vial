defmodule Aludel.Web.SuiteLive.Index do
  @moduledoc """
  LiveView for listing evaluation suites.

  Displays all suites with their associated prompt names.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.Projects

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    suites = Evals.list_suites_with_prompt()
    projects = Projects.list_projects(type: :suite)

    socket =
      socket
      |> assign(:page_title, "Suites")
      |> assign(:suites, suites)
      |> assign(:projects, projects)
      |> assign(:expanded_projects, Map.get(socket.assigns, :expanded_projects, []))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    suite = Evals.get_suite!(id)

    case Evals.delete_suite(suite) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:suites, Evals.list_suites_with_prompt())
         |> assign(:projects, Projects.list_projects(type: :suite))
         |> put_flash(:info, "Suite deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete suite")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_project", %{"project_id" => project_id}, socket) do
    expanded =
      if project_id in socket.assigns.expanded_projects do
        List.delete(socket.assigns.expanded_projects, project_id)
      else
        [project_id | socket.assigns.expanded_projects]
      end

    {:noreply, assign(socket, :expanded_projects, expanded)}
  end

  @impl Phoenix.LiveView
  def handle_event("create_project", %{"project" => project_params}, socket) do
    case Projects.create_project(Map.put(project_params, "type", "suite")) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:projects, Projects.list_projects(type: :suite))
         |> assign(:suites, Evals.list_suites_with_prompt())
         |> put_flash(:info, "Project created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_project", %{"project" => project_params}, socket) do
    project = Projects.get_project!(project_params["id"])

    case Projects.update_project(project, project_params) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:projects, Projects.list_projects(type: :suite))
         |> assign(:suites, Evals.list_suites_with_prompt())
         |> put_flash(:info, "Project updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)

    case Projects.delete_project(project) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:projects, Projects.list_projects(type: :suite))
         |> assign(:suites, Evals.list_suites_with_prompt())
         |> put_flash(:info, "Project deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("phx-noop", _params, socket) do
    {:noreply, socket}
  end
end
