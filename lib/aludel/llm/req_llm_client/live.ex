defmodule Aludel.LLM.ReqLLMClient.Live do
  @moduledoc """
  Live implementation that delegates to ReqLLM for actual API calls.
  """

  @behaviour Aludel.LLM.ReqLLMClient

  @impl true
  def generate_text(model_spec, messages, opts) do
    ReqLLM.generate_text(model_spec, messages, opts)
  end
end
