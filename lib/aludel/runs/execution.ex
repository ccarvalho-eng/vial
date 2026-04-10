defmodule Aludel.Runs.Execution do
  @moduledoc """
  Result of executing a run across one or more providers.
  """

  alias Aludel.Runs.{Run, RunResult}

  @enforce_keys [:failures, :provider_results, :run, :status]

  @type failure :: %{
          provider_id: Ecto.UUID.t(),
          provider_name: String.t(),
          reason: term()
        }

  @type status :: :ok | :partial_failure | :error

  @type t :: %__MODULE__{
          failures: [failure()],
          provider_results: [RunResult.t()],
          run: Run.t(),
          status: status()
        }

  defstruct [:failures, :provider_results, :run, :status]
end
