defmodule Vial.Web.DashboardLive do
  @moduledoc false

  use Phoenix.LiveView

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:mounted, true)
      |> assign(:session_data, session)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-3xl font-bold mb-4">Vial Dashboard</h1>
      <div class="space-y-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Welcome to Vial</h2>
            <p>This is the embeddable Vial dashboard</p>
            <div class="mt-4 space-y-2">
              <p><strong>Access Level:</strong> {@access}</p>
              <p><strong>Vial Name:</strong> {@vial_name}</p>
            </div>
          </div>
        </div>
        <div class="alert alert-info">
          <span>LiveView consolidation is in progress. Full navigation coming soon.</span>
        </div>
      </div>
    </div>
    """
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
