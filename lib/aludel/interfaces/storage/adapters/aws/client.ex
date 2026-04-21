defmodule Aludel.Interfaces.Storage.Adapters.AWS.Client do
  @moduledoc """
  Behaviour for the AWS storage adapter's S3 client boundary.
  """

  @callback put_object(String.t(), String.t(), binary(), String.t(), keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback get_object(String.t(), String.t(), keyword()) ::
              {:ok, binary()} | {:error, term()}

  @callback delete_object(String.t(), String.t(), keyword()) ::
              :ok | {:error, term()}
end
