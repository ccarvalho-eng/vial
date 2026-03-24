defmodule Vial.Web.Cache do
  @moduledoc """
  ETS-based cache for Vial Web dashboard.
  """

  use GenServer

  @table __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expire_at}] ->
        if System.system_time(:second) < expire_at do
          {:ok, value}
        else
          :error
        end

      [] ->
        :error
    end
  end

  def put(key, value, ttl) do
    expire_at = System.system_time(:second) + ttl
    :ets.insert(@table, {key, value, expire_at})
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
