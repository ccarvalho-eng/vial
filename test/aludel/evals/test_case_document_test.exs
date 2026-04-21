defmodule Aludel.Evals.TestCaseDocumentTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals.TestCaseDocument

  describe "create_changeset/2" do
    test "valid changeset with upload fields" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test_input.txt",
          content_type: "text/plain",
          data: "sample file content",
          size_bytes: 19
        })

      assert changeset.valid?
    end

    test "requires test_case_id" do
      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          filename: "test.txt",
          content_type: "text/plain",
          data: "content",
          size_bytes: 7
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).test_case_id
    end

    test "requires filename" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          content_type: "text/plain",
          data: "content",
          size_bytes: 7
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).filename
    end

    test "requires content_type" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          data: "content",
          size_bytes: 7
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content_type
    end

    test "requires data" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          content_type: "text/plain",
          size_bytes: 7
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).data
    end

    test "requires size_bytes" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          content_type: "text/plain",
          data: "content"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).size_bytes
    end

    test "validates content_type is in allowed list" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.exe",
          content_type: "application/x-msdownload",
          data: <<1, 2, 3>>,
          size_bytes: 100
        })

      refute changeset.valid?
      assert "is not a supported document type" in errors_on(changeset).content_type
    end

    test "validates size is within limit" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "huge.pdf",
          content_type: "application/pdf",
          data: <<1, 2, 3>>,
          size_bytes: 11 * 1024 * 1024
        })

      refute changeset.valid?
      assert "file size must be less than 10MB" in errors_on(changeset).size_bytes
    end

    test "validates filename length" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: String.duplicate("a", 256),
          content_type: "text/plain",
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).filename
    end

    test "validates content_type length" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          content_type: String.duplicate("a", 101),
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).content_type
    end

    test "rejects storage metadata for uploaded documents" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.create_changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          content_type: "text/plain",
          data: "content",
          size_bytes: 7,
          storage_key: "documents/test.txt",
          storage_backend: "local"
        })

      refute changeset.valid?

      assert "must be blank for uploaded documents" in errors_on(changeset).storage_key
      assert "must be blank for uploaded documents" in errors_on(changeset).storage_backend
    end
  end

  describe "changeset/2" do
    test "valid changeset for an externally stored document" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test_input.txt",
          content_type: "text/plain",
          size_bytes: 19,
          storage_key: "test_case_documents/doc-id/test_input.txt",
          storage_backend: "local"
        })

      assert changeset.valid?
    end

    test "rejects persisted documents with inline data" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test_input.txt",
          content_type: "text/plain",
          data: "sample file content",
          size_bytes: 19,
          storage_key: "test_case_documents/doc-id/test_input.txt",
          storage_backend: "local"
        })

      refute changeset.valid?
      assert "must be blank for persisted documents" in errors_on(changeset).data
    end

    test "requires storage_key" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test_input.txt",
          content_type: "text/plain",
          size_bytes: 19,
          storage_backend: "local"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).storage_key
    end

    test "requires storage_backend" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test_input.txt",
          content_type: "text/plain",
          size_bytes: 19,
          storage_key: "test_case_documents/doc-id/test_input.txt"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).storage_backend
    end
  end

  describe "externally_stored?/1" do
    test "returns true when a storage key is present" do
      assert TestCaseDocument.externally_stored?(%TestCaseDocument{
               storage_key: "test_case_documents/doc-id/test.txt"
             })
    end

    test "returns false when a storage key is missing" do
      refute TestCaseDocument.externally_stored?(%TestCaseDocument{})
    end
  end
end
