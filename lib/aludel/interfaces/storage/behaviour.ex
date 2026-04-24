defmodule Aludel.Interfaces.Storage.Behaviour do
  @moduledoc """
  Behaviour for external document storage adapters.
  """

  @type config :: keyword()

  @callback put(String.t(), binary(), String.t(), config()) ::
              {:ok, String.t()} | {:error, term()}
  @callback get(String.t(), config()) :: {:ok, binary()} | {:error, term()}
  @callback delete(String.t(), config()) :: :ok | {:error, term()}
end
