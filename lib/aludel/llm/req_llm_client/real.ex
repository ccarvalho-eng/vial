defmodule Aludel.LLM.ReqLLMClient.Real do
  @moduledoc """
  Production implementation that calls real ReqLLM.
  """

  @behaviour Aludel.LLM.ReqLLMClient

  @impl true
  def generate_text(model_spec, messages, opts) do
    ReqLLM.generate_text(model_spec, messages, opts)
  end
end
