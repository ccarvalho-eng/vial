defmodule Aludel.Interfaces.Storage.Adapters.AWS.ExAwsClient do
  @moduledoc """
  Default AWS client implementation backed by `ExAws.S3`.
  """

  @behaviour Aludel.Interfaces.Storage.Adapters.AWS.Client

  alias Aludel.Interfaces.Storage.Adapters.AWS.HTTPClient
  alias ExAws.S3

  @impl true
  def put_object(bucket, key, data, content_type, config) do
    bucket
    |> S3.put_object(key, data, put_options(config, content_type))
    |> ExAws.request(request_config(config))
    |> case do
      {:ok, _response} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_object(bucket, key, config) do
    bucket
    |> S3.get_object(key, Keyword.get(config, :get_options, []))
    |> ExAws.request(request_config(config))
    |> case do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, body} when is_binary(body) -> {:ok, body}
      {:ok, response} -> {:error, {:unexpected_response, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_object(bucket, key, config) do
    bucket
    |> S3.delete_object(key, Keyword.get(config, :delete_options, []))
    |> ExAws.request(request_config(config))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_options(config, content_type) do
    config
    |> Keyword.get(:put_options, [])
    |> Keyword.put_new(:content_type, content_type)
  end

  defp request_config(config) do
    config
    |> Keyword.get(:request_config, [])
    |> Keyword.put_new(:http_client, HTTPClient)
    |> then(&Keyword.merge(common_request_config(config), &1))
  end

  defp common_request_config(config) do
    [:region, :access_key_id, :secret_access_key, :security_token]
    |> Enum.flat_map(fn key ->
      case Keyword.fetch(config, key) do
        {:ok, value} -> [{key, value}]
        :error -> []
      end
    end)
  end
end
