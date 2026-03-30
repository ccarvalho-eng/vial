defmodule Aludel.LLM.ReqLLMClient do
  @moduledoc """
  Behaviour wrapper for ReqLLM to enable Mox testing.
  """

  @callback generate_text(
              model_spec :: term(),
              messages :: String.t() | list(),
              opts :: keyword()
            ) ::
              {:ok, ReqLLM.Response.t()} | {:error, term()}

  def generate_text(model_spec, messages, opts \\ []) do
    impl().generate_text(model_spec, messages, opts)
  end

  defp impl do
    Application.get_env(:aludel, :req_llm_client, Aludel.LLM.ReqLLMClient.Live)
  end
end
