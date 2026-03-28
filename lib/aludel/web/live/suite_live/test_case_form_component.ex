defmodule Aludel.Web.SuiteLive.TestCaseFormComponent do
  @moduledoc """
  LiveComponent for test case form.

  Provides a form interface for creating and editing test cases with
  variables, documents, and assertions.
  """

  use Aludel.Web, :live_component

  alias Aludel.Evals.TestCase

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    test_case = assigns[:test_case] || %TestCase{}

    socket =
      socket
      |> assign(assigns)
      |> assign(:test_case, test_case)
      |> allow_upload(:documents,
        accept: ~w(.txt .md .pdf .doc .docx),
        max_entries: 10,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("add_variable", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("add_assertion", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.form for={%{}} phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <!-- Variables Section -->
          <div>
            <h3 class="text-lg font-medium">Variables</h3>
            <div class="mt-2">
              <button type="button" phx-click="add_variable" phx-target={@myself}>
                Add Variable
              </button>
            </div>
          </div>
          
    <!-- Documents Section -->
          <div>
            <h3 class="text-lg font-medium">Documents</h3>
            <div class="mt-2" phx-drop-target={@uploads.documents.ref}>
              <!-- Placeholder for file upload -->
            </div>
          </div>
          
    <!-- Assertions Section -->
          <div>
            <h3 class="text-lg font-medium">Assertions</h3>
            <div class="mt-2">
              <button type="button" phx-click="add_assertion" phx-target={@myself}>
                Add Assertion
              </button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
