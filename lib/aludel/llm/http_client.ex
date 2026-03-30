defmodule Aludel.LLM.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client abstraction.

  Allows mocking HTTP requests in tests.
  """

  @callback post(url :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  def post(url, opts) do
    impl().post(url, opts)
  end

  defp impl do
    Application.get_env(:aludel, :http_client, Aludel.LLM.HTTPClient.Req)
  end
end
