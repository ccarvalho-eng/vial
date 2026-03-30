defmodule Aludel.LLM.HTTPClient.Req do
  @moduledoc """
  Production HTTP client implementation using Req.
  """

  @behaviour Aludel.LLM.HTTPClient

  @impl true
  def post(url, opts) do
    Req.post(url, opts)
  end
end
