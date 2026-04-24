defmodule Aludel.Interfaces.Storage.Adapters.AWS.HTTPClient do
  @moduledoc """
  ExAws HTTP client implementation backed by Req.

  This stays under the storage adapter namespace so the AWS-specific
  transport glue does not leak into the wider application surface.
  """

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, http_opts) do
    request =
      http_opts
      |> req_options()
      |> then(&Req.new(Keyword.merge([decode_body: false, retry: false], &1)))

    case Req.request(request, method: method, url: url, body: body, headers: headers) do
      {:ok, response} ->
        {:ok,
         %{
           status_code: response.status,
           headers: Req.get_headers_list(response),
           body: response.body
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  defp req_options(http_opts) when is_list(http_opts) do
    []
    |> maybe_put(:receive_timeout, http_opts[:recv_timeout] || http_opts[:timeout])
    |> maybe_put(:pool_timeout, http_opts[:pool_timeout])
    |> maybe_put(:proxy, http_opts[:proxy])
    |> maybe_put_connect_timeout(http_opts[:connect_timeout])
    |> maybe_put_ssl_options(http_opts[:ssl_options])
  end

  defp req_options(_http_opts), do: []

  defp maybe_put(options, _key, nil), do: options
  defp maybe_put(options, key, value), do: Keyword.put(options, key, value)

  defp maybe_put_connect_timeout(options, nil), do: options

  defp maybe_put_connect_timeout(options, timeout) do
    connect_options =
      options
      |> Keyword.get(:connect_options, [])
      |> Keyword.put(:timeout, timeout)

    Keyword.put(options, :connect_options, connect_options)
  end

  defp maybe_put_ssl_options(options, nil), do: options

  defp maybe_put_ssl_options(options, ssl_options) do
    connect_options =
      options
      |> Keyword.get(:connect_options, [])
      |> Keyword.put(:transport_opts, ssl_options)

    Keyword.put(options, :connect_options, connect_options)
  end
end
