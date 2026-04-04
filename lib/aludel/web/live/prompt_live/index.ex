defmodule Aludel.Web.PromptLive.Index do
  @moduledoc """
  LiveView for listing and filtering prompts.
  """

  use Aludel.Web, :live_view

  alias Aludel.Projects
  alias Aludel.Prompts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")
    page_size = 20
    search_query = params["search"] || ""
    selected_tags = parse_tags_param(params["tags"] || params["tag"])
    selected_project_id = params["project_id"]

    projects = Projects.list_projects(type: :prompt)
    all_prompts = Prompts.list_prompts()
    all_tags = extract_all_tags(all_prompts)

    prompts_params = %{page: page, page_size: page_size}

    prompts_params =
      if selected_project_id,
        do: Map.put(prompts_params, :project_id, selected_project_id),
        else: prompts_params

    paginated = Prompts.list_prompts(prompts_params)

    filtered_prompts =
      filter_prompts(paginated.entries, search_query, selected_tags)

    socket =
      socket
      |> assign(:page_title, "Prompts")
      |> assign(:projects, projects)
      |> assign(:prompts, filtered_prompts)
      |> assign(:pagination, paginated)
      |> assign(:all_tags, all_tags)
      |> assign(:search_query, search_query)
      |> assign(:selected_tags, selected_tags)
      |> assign(:selected_project_id, selected_project_id)
      |> assign(:expanded_projects, Map.get(socket.assigns, :expanded_projects, []))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    prompt = Prompts.get_prompt!(id)
    {:ok, _} = Prompts.delete_prompt(prompt)

    all_prompts = Prompts.list_prompts()

    filtered =
      filter_prompts(all_prompts, socket.assigns.search_query, socket.assigns.selected_tags)

    {:noreply,
     socket
     |> assign(:prompts, filtered)
     |> assign(:all_tags, extract_all_tags(all_prompts))
     |> put_flash(:info, "Prompt deleted successfully")}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     push_patch(socket,
       to: aludel_path("prompts", build_query_params(query, socket.assigns.selected_tags))
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_tag", %{"tag" => tag}, socket) do
    selected_tags =
      if tag in socket.assigns.selected_tags do
        List.delete(socket.assigns.selected_tags, tag)
      else
        [tag | socket.assigns.selected_tags]
      end

    {:noreply,
     push_patch(socket,
       to: aludel_path("prompts", build_query_params(socket.assigns.search_query, selected_tags))
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: aludel_path("prompts"))}
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
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         aludel_path(
           "prompts",
           Map.merge(
             build_query_params(socket.assigns.search_query, socket.assigns.selected_tags),
             %{"project_id" => project_id, "page" => "1"}
           )
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_project", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         aludel_path(
           "prompts",
           build_query_params(socket.assigns.search_query, socket.assigns.selected_tags)
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("create_project", %{"project" => project_params}, socket) do
    case Projects.create_project(Map.put(project_params, "type", "prompt")) do
      {:ok, _project} ->
        projects = Projects.list_projects(type: :prompt)

        {:noreply,
         socket
         |> assign(:projects, projects)
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
         |> put_flash(:info, "Project updated successfully")
         |> push_patch(to: aludel_path("prompts"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update project")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)
    {:ok, _} = Projects.delete_project(project)

    {:noreply,
     socket
     |> put_flash(:info, "Project deleted successfully")
     |> push_patch(to: aludel_path("prompts"))}
  end

  @impl Phoenix.LiveView
  def handle_event("phx-noop", _params, socket) do
    {:noreply, socket}
  end

  defp filter_prompts(prompts, search_query, selected_tags) do
    prompts
    |> filter_by_search(search_query)
    |> filter_by_tags(selected_tags)
  end

  defp filter_by_search(prompts, ""), do: prompts

  defp filter_by_search(prompts, query) do
    query = String.downcase(query)

    Enum.filter(prompts, fn prompt ->
      String.contains?(String.downcase(prompt.name), query) ||
        (prompt.description && String.contains?(String.downcase(prompt.description), query))
    end)
  end

  defp filter_by_tags(prompts, []), do: prompts

  defp filter_by_tags(prompts, selected_tags) do
    Enum.filter(prompts, fn prompt ->
      Enum.any?(selected_tags, fn tag -> tag in (prompt.tags || []) end)
    end)
  end

  defp extract_all_tags(prompts) do
    prompts
    |> Enum.flat_map(fn prompt -> prompt.tags || [] end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp parse_tags_param(nil), do: []
  defp parse_tags_param(""), do: []
  defp parse_tags_param(tags_string), do: String.split(tags_string, ",")

  defp build_query_params("", []), do: %{}
  defp build_query_params(query, []), do: %{"search" => query}
  defp build_query_params("", tags), do: %{"tags" => Enum.join(tags, ",")}
  defp build_query_params(query, tags), do: %{"search" => query, "tags" => Enum.join(tags, ",")}
end
