defmodule Aludel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Aludel.Interfaces.Storage.Adapters.GCS

  @impl true
  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: Aludel.PubSub},
        {Task.Supervisor, name: Aludel.Runs.ExecutorSupervisor},
        {Task.Supervisor, name: Aludel.TaskSupervisor}
      ] ++ storage_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Aludel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp storage_children do
    case Aludel.Storage.adapter() do
      GCS -> [{Goth, name: Aludel.Goth}]
      _other -> []
    end
  end
end
