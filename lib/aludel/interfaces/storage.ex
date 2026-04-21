defmodule Aludel.Storage do
  @moduledoc """
  Domain-facing facade for document storage backends.

  Test case documents are persisted through the configured storage adapter.
  """

  alias Aludel.Evals.TestCaseDocument
  alias Aludel.Interfaces.Storage.Adapters.Local

  @type config :: keyword()
  @type error_reason :: term()

  @default_adapter Local

  @spec put(String.t(), binary(), String.t()) :: {:ok, String.t()} | {:error, error_reason()}
  def put(key, data, content_type) do
    adapter().put(key, data, content_type, config())
  end

  @spec get(String.t(), keyword()) :: {:ok, binary()} | {:error, error_reason()}
  def get(key, opts \\ []) do
    with {:ok, storage_adapter} <- adapter_for(opts) do
      storage_adapter.get(key, config_for(storage_adapter, opts))
    end
  end

  @spec delete(String.t(), keyword()) :: :ok | {:error, error_reason()}
  def delete(key, opts \\ []) do
    with {:ok, storage_adapter} <- adapter_for(opts) do
      storage_adapter.delete(key, config_for(storage_adapter, opts))
    end
  end

  @spec read(TestCaseDocument.t()) :: {:ok, binary()} | {:error, error_reason()}
  def read(%TestCaseDocument{storage_key: key, storage_backend: backend})
      when is_binary(key) and is_binary(backend) do
    get(key, storage_backend: backend)
  end

  def read(%TestCaseDocument{}), do: {:error, :missing_document_data}

  @spec adapter() :: module()
  def adapter do
    case config() do
      adapter when is_atom(adapter) and not is_nil(adapter) ->
        adapter

      config when is_list(config) ->
        Keyword.get(config, :adapter, @default_adapter)

      _ ->
        @default_adapter
    end
  end

  @spec config() :: config()
  def config do
    :aludel
    |> Application.get_env(__MODULE__, [])
    |> resolve_system_values()
  end

  @spec backend_name(module()) :: String.t()
  def backend_name(adapter \\ adapter()), do: Atom.to_string(adapter)

  @spec storage_key(Ecto.UUID.t(), String.t()) :: String.t()
  def storage_key(document_id, filename) do
    Path.join(["test_case_documents", document_id, sanitize_filename(filename)])
  end

  @spec resolve_backend(String.t() | nil) :: {:ok, module()} | {:error, :unknown_storage_backend}
  def resolve_backend(nil), do: {:ok, adapter()}

  def resolve_backend(backend) when is_binary(backend) do
    module = String.to_existing_atom(backend)

    if Code.ensure_loaded?(module) do
      {:ok, module}
    else
      {:error, :unknown_storage_backend}
    end
  rescue
    ArgumentError -> {:error, :unknown_storage_backend}
  end

  defp adapter_for(opts) do
    opts
    |> Keyword.get(:storage_backend)
    |> resolve_backend()
  end

  defp config_for(storage_adapter, opts) do
    base_config =
      config()
      |> Keyword.drop([:adapter, :backends])
      |> Keyword.merge(backend_config(storage_adapter))

    case Keyword.get(opts, :config) do
      nil -> base_config
      override when is_list(override) -> Keyword.merge(base_config, override)
    end
  end

  defp backend_config(storage_adapter) do
    case Keyword.get(config(), :backends, []) do
      backends when is_list(backends) ->
        list_backend_config(backends, storage_adapter)

      backends when is_map(backends) ->
        Map.get(backends, storage_adapter) ||
          Map.get(backends, Atom.to_string(storage_adapter), [])

      _ ->
        []
    end
  end

  defp list_backend_config(backends, storage_adapter) do
    backend_name = Atom.to_string(storage_adapter)

    Enum.find_value(backends, [], fn
      {^storage_adapter, config} when is_list(config) -> config
      {^backend_name, config} when is_list(config) -> config
      _other -> nil
    end)
  end

  defp resolve_system_values(config) when is_list(config) do
    Enum.map(config, fn
      {key, {:system, env_var}} -> {key, System.get_env(env_var)}
      {key, value} -> {key, resolve_system_values(value)}
    end)
  end

  defp resolve_system_values(config) when is_map(config) do
    Map.new(config, fn {key, value} -> {key, resolve_system_values(value)} end)
  end

  defp resolve_system_values(value), do: value

  defp sanitize_filename(filename) do
    filename
    |> Path.basename()
    |> String.replace(~r/[^a-zA-Z0-9._-]+/u, "_")
  end
end
