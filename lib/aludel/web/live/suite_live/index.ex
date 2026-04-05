defmodule Aludel.Web.SuiteLive.Index do
  @moduledoc """
  LiveView for listing evaluation suites.

  Displays all suites with their associated prompt names.
  """

  use Aludel.Web, :live_view

  alias Aludel.Evals
  alias Aludel.Projects
  alias Aludel.Projects.Project

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
      |> assign(:create_project_form, project_form(%Project{}))
      |> assign(:edit_project_forms, build_edit_project_forms(projects))
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
        projects = Projects.list_projects(type: :suite)
        suites = Evals.list_suites_with_prompt()

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:suites, suites)
         |> assign(:create_project_form, project_form(%Project{}))
         |> assign(:edit_project_forms, build_edit_project_forms(projects))
         |> put_flash(:info, "Project created successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:create_project_form, to_form(changeset, as: :project))
         |> put_flash(:error, "Failed to create project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate_create_project", %{"project" => project_params}, socket) do
    changeset =
      %Project{}
      |> Projects.change_project(Map.put(project_params, "type", "suite"))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :create_project_form, to_form(changeset, as: :project))}
  end

  @impl Phoenix.LiveView
  def handle_event("update_project", %{"project" => project_params}, socket) do
    project = Projects.get_project!(project_params["id"])

    case Projects.update_project(project, project_params) do
      {:ok, _project} ->
        projects = Projects.list_projects(type: :suite)
        suites = Evals.list_suites_with_prompt()

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:suites, suites)
         |> assign(:edit_project_forms, build_edit_project_forms(projects))
         |> put_flash(:info, "Project updated successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(
           :edit_project_forms,
           Map.put(
             socket.assigns.edit_project_forms,
             project.id,
             to_form(changeset, as: :project)
           )
         )
         |> put_flash(:error, "Failed to update project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate_update_project", %{"project" => project_params}, socket) do
    project = Projects.get_project!(project_params["id"])

    changeset =
      project
      |> Projects.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(
       socket,
       :edit_project_forms,
       Map.put(socket.assigns.edit_project_forms, project.id, to_form(changeset, as: :project))
     )}
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

  defp project_form(project) do
    project
    |> Projects.change_project(%{})
    |> to_form(as: :project)
  end

  defp build_edit_project_forms(projects) do
    Map.new(projects, fn project ->
      {project.id, project |> Projects.change_project(%{}) |> to_form(as: :project)}
    end)
  end
end
