defmodule Aludel.Evals.TestCaseDocumentTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals.TestCaseDocument

  describe "changeset/2" do
    test "valid changeset with all fields" do
      test_case = test_case_fixture()

      changeset =
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
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
        TestCaseDocument.changeset(%TestCaseDocument{}, %{
          test_case_id: test_case.id,
          filename: "test.txt",
          content_type: String.duplicate("a", 101),
          data: <<1, 2, 3>>,
          size_bytes: 3
        })

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).content_type
    end
  end
end
