defmodule Vial.Web.DashboardLive do
  @moduledoc false

  use Phoenix.LiveView

  import Phoenix.Component

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-3xl font-bold mb-4">Vial Dashboard</h1>
      <div class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.nav_card title="Prompts" path="/prompts" description="Manage your AI prompts" />
          <.nav_card title="Runs" path="/runs/new" description="Execute prompt runs" />
          <.nav_card title="Suites" path="/suites" description="Test suites and evaluations" />
          <.nav_card title="Providers" path="/providers" description="Configure AI providers" />
        </div>

        <div class="mt-6">
          <div class="alert alert-success">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="stroke-current shrink-0 h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <div>
              <h3 class="font-bold">Vial Embedded Successfully</h3>
              <div class="text-xs">
                Access Level: {@access || "all"} | Instance: {@vial_name || "Vial"}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp nav_card(assigns) do
    ~H"""
    <a href={@path} class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow">
      <div class="card-body">
        <h2 class="card-title">{@title}</h2>
        <p>{@description}</p>
        <div class="card-actions justify-end">
          <button class="btn btn-primary btn-sm">Go →</button>
        </div>
      </div>
    </a>
    """
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
