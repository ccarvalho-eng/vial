defmodule Aludel.Evals.DocumentIngestion do
  @moduledoc """
  Validates and persists uploaded documents for suite test cases.
  """

  alias Aludel.Evals
  alias Aludel.FileValidation

  @type ingest_result ::
          {:success, String.t()}
          | {:failed, String.t(), String.t()}

  @spec ingest(String.t(), Phoenix.LiveView.UploadEntry.t(), binary()) :: ingest_result()
  def ingest(path, entry, test_case_id) do
    case File.read(path) do
      {:ok, data} ->
        validate_and_persist(data, entry, test_case_id)

      {:error, reason} ->
        {:failed, entry.client_name, :file.format_error(reason)}
    end
  end

  defp validate_and_persist(data, entry, test_case_id) do
    case FileValidation.validate(data, entry.client_type) do
      :ok ->
        persist_document(entry, data, test_case_id)

      {:error, reason} ->
        {:failed, entry.client_name, reason}
    end
  end

  defp persist_document(entry, data, test_case_id) do
    case Evals.create_test_case_document(%{
           test_case_id: test_case_id,
           filename: entry.client_name,
           content_type: entry.client_type,
           data: data,
           size_bytes: entry.client_size
         }) do
      {:ok, _document} ->
        {:success, entry.client_name}

      {:error, _changeset} ->
        {:failed, entry.client_name, "Database error"}
    end
  end
end
