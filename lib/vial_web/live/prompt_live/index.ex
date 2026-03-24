defmodule VialWeb.PromptLive.Index do
  @moduledoc """
  LiveView for listing and filtering prompts.
  """

  use VialWeb, :live_view

  alias Vial.Prompts
  alias Vial.Hooks

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    repo = Hooks.get_repo(socket)
    all_prompts = Prompts.list_prompts(repo)
    all_tags = extract_all_tags(all_prompts)
    search_query = params["search"] || ""
    selected_tags = parse_tags_param(params["tags"] || params["tag"])

    prompts = filter_prompts(all_prompts, search_query, selected_tags)

    socket =
      socket
      |> assign(:page_title, "Prompts")
      |> assign(:prompts, prompts)
      |> assign(:all_tags, all_tags)
      |> assign(:search_query, search_query)
      |> assign(:selected_tags, selected_tags)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    repo = Hooks.get_repo(socket)
    prompt = Prompts.get_prompt!(repo, id)
    {:ok, _} = Prompts.delete_prompt(repo, prompt)

    all_prompts = Prompts.list_prompts(repo)

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
    query_params = build_query_params(query, socket.assigns.selected_tags)

    path =
      if query_params == %{}, do: "/prompts", else: "/prompts?#{URI.encode_query(query_params)}"

    {:noreply, push_patch(socket, to: vial_path(socket, path))}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_tag", %{"tag" => tag}, socket) do
    selected_tags =
      if tag in socket.assigns.selected_tags do
        List.delete(socket.assigns.selected_tags, tag)
      else
        [tag | socket.assigns.selected_tags]
      end

    query_params = build_query_params(socket.assigns.search_query, selected_tags)

    path =
      if query_params == %{}, do: "/prompts", else: "/prompts?#{URI.encode_query(query_params)}"

    {:noreply, push_patch(socket, to: vial_path(socket, path))}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: vial_path(socket, "/prompts"))}
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
