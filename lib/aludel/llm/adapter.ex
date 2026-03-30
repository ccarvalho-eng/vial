defmodule Aludel.LLM.Adapter do
  @moduledoc """
  Behaviour for LLM provider adapters.

  Each adapter implements provider-specific logic for calling LLM APIs.
  """

  @type document_input :: %{
          data: binary(),
          content_type: String.t()
        }

  @type adapter_response :: %{
          content: String.t(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer()
        }

  @type error_reason ::
          :missing_api_key
          | {:auth_error, String.t()}
          | {:rate_limit, non_neg_integer() | nil}
          | {:invalid_request, String.t()}
          | {:api_error, non_neg_integer(), String.t()}
          | {:network_error, term()}

  @doc """
  Generates completion from the LLM provider.

  ## Parameters
    - model: Model identifier string
    - prompt: Text prompt to send
    - config: Map of provider-specific configuration
    - opts: Keyword list of options including :documents

  ## Returns
    - `{:ok, adapter_response}` on success
    - `{:error, error_reason}` on failure
  """
  @callback generate(
              model :: String.t(),
              prompt :: String.t(),
              config :: map(),
              opts :: keyword()
            ) ::
              {:ok, adapter_response()} | {:error, error_reason()}
end
