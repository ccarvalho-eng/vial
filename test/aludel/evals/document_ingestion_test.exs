defmodule Aludel.Evals.DocumentIngestionTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals
  alias Aludel.Evals.DocumentIngestion

  describe "ingest/3" do
    test "persists a valid uploaded document" do
      test_case = test_case_fixture()
      path = write_temp_file("%PDF-1.4\ncontent")

      entry = %Phoenix.LiveView.UploadEntry{
        client_name: "sample.pdf",
        client_size: byte_size("%PDF-1.4\ncontent"),
        client_type: "application/pdf"
      }

      assert {:success, "sample.pdf"} = DocumentIngestion.ingest(path, entry, test_case.id)

      document = Evals.get_test_case_with_documents!(test_case.id).documents |> List.first()
      assert document.filename == "sample.pdf"
      assert document.content_type == "application/pdf"
    end

    test "rejects a document when the content does not match the claimed type" do
      test_case = test_case_fixture()
      path = write_temp_file("not really a pdf")

      entry = %Phoenix.LiveView.UploadEntry{
        client_name: "sample.pdf",
        client_size: byte_size("not really a pdf"),
        client_type: "application/pdf"
      }

      assert {:failed, "sample.pdf", "File content does not match type application/pdf"} =
               DocumentIngestion.ingest(path, entry, test_case.id)
    end

    test "returns a readable error when the upload temp file cannot be read" do
      entry = %Phoenix.LiveView.UploadEntry{
        client_name: "sample.pdf",
        client_size: 0,
        client_type: "application/pdf"
      }

      assert {:failed, "sample.pdf", reason} =
               DocumentIngestion.ingest("/tmp/does-not-exist-aludel", entry, Ecto.UUID.generate())

      assert to_string(reason) =~ "no such file or directory"
    end

    test "returns a database error when the document cannot be persisted" do
      path = write_temp_file("%PDF-1.4\ncontent")

      entry = %Phoenix.LiveView.UploadEntry{
        client_name: "sample.pdf",
        client_size: byte_size("%PDF-1.4\ncontent"),
        client_type: "application/pdf"
      }

      assert {:failed, "sample.pdf", reason} =
               DocumentIngestion.ingest(path, entry, Ecto.UUID.generate())

      assert reason =~ "test_case_id does not exist"
    end
  end

  defp write_temp_file(contents) do
    path = Path.join(System.tmp_dir!(), "aludel-upload-#{System.unique_integer([:positive])}")
    File.write!(path, contents)
    path
  end
end
