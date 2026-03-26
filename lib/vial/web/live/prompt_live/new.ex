defmodule Vial.Web.PromptLive.New do
  @moduledoc """
  LiveView for creating and editing prompts.

  Handles both :new and :edit live actions, with real-time variable
  extraction from templates.
  """

  use Vial.Web, :live_view

  alias Vial.Prompts
  alias Vial.Prompts.Prompt

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"prompt" => prompt_params}, socket) do
    variables =
      prompt_params
      |> Map.get("template", "")
      |> Prompts.extract_variables()

    changeset =
      socket.assigns.prompt
      |> Prompts.change_prompt(prompt_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:variables, variables)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"prompt" => prompt_params}, socket) do
    save_prompt(socket, socket.assigns.live_action, prompt_params)
  end

  defp apply_action(socket, :new, _params) do
    prompt = %Prompt{}
    changeset = Prompts.change_prompt(prompt)

    socket
    |> assign(:page_title, "New Prompt")
    |> assign(:prompt, prompt)
    |> assign(:form, to_form(changeset))
    |> assign(:variables, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    prompt = Prompts.get_prompt_with_versions!(id)

    # Get the latest version's template to pre-populate the form
    latest_version = List.first(prompt.versions)
    latest_template = if latest_version, do: latest_version.template, else: ""

    # Convert tags array to comma-separated string for form display
    form_data = %{
      "name" => prompt.name,
      "description" => prompt.description,
      "tags" => Enum.join(prompt.tags, ", "),
      "template" => latest_template
    }

    changeset = Prompts.change_prompt(prompt, form_data)

    # Extract variables from latest template
    variables = Prompts.extract_variables(latest_template)

    socket
    |> assign(:page_title, "Edit Prompt")
    |> assign(:prompt, prompt)
    |> assign(:form, to_form(changeset))
    |> assign(:variables, variables)
  end

  defp save_prompt(socket, :new, prompt_params) do
    case Prompts.create_prompt(prompt_params) do
      {:ok, prompt} ->
        # Create initial version if template provided
        template = Map.get(prompt_params, "template", "")

        if template != "" do
          Prompts.create_prompt_version(prompt, template)
        end

        {:noreply,
         socket
         |> put_flash(:info, "Prompt created successfully")
         |> push_navigate(to: vial_path("prompts/#{prompt.id}"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_prompt(socket, :edit, prompt_params) do
    prompt = socket.assigns.prompt
    new_template = Map.get(prompt_params, "template", "")

    # Get the latest version's template to compare
    latest_version = List.first(prompt.versions)
    latest_template = if latest_version, do: latest_version.template, else: ""

    case Prompts.update_prompt(prompt, prompt_params) do
      {:ok, updated_prompt} ->
        # Only create new version if template changed and is not empty
        if new_template != "" and new_template != latest_template do
          Prompts.create_prompt_version(updated_prompt, new_template)
        end

        {:noreply,
         socket
         |> put_flash(:info, "Prompt updated successfully")
         |> push_navigate(to: vial_path("prompts/#{updated_prompt.id}"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
