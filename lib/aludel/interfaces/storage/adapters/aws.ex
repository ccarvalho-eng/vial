defmodule Aludel.Interfaces.Storage.Adapters.AWS do
  @moduledoc """
  AWS S3-backed document storage adapter.
  """

  @behaviour Aludel.Interfaces.Storage.Behaviour

  alias Aludel.Interfaces.Storage.Adapters.AWS.ExAwsClient

  @impl true
  def put(key, data, content_type, config) do
    with {:ok, bucket} <- fetch_bucket(config) do
      client(config).put_object(bucket, key, data, content_type, config)
    end
  end

  @impl true
  def get(key, config) do
    with {:ok, bucket} <- fetch_bucket(config) do
      client(config).get_object(bucket, key, config)
    end
  end

  @impl true
  def delete(key, config) do
    with {:ok, bucket} <- fetch_bucket(config) do
      client(config).delete_object(bucket, key, config)
    end
  end

  defp client(config), do: Keyword.get(config, :client, ExAwsClient)

  defp fetch_bucket(config) do
    case Keyword.get(config, :bucket) do
      bucket when is_binary(bucket) and bucket != "" -> {:ok, bucket}
      _ -> {:error, :missing_bucket}
    end
  end
end
