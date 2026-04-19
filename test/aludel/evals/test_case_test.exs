defmodule Aludel.Evals.TestCaseTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals.TestCase
  alias Aludel.Evals.TestCaseDocument

  describe "changeset/2" do
    test "valid changeset with all fields" do
      suite = suite_fixture()

      changeset =
        TestCase.changeset(%TestCase{}, %{
          suite_id: suite.id,
          variable_values: %{"name" => "John"},
          assertions: [
            %{"type" => "contains", "value" => "Hello"},
            %{"type" => "not_contains", "value" => "Goodbye"},
            %{"type" => "regex", "value" => "^Hello"},
            %{"type" => "exact_match", "value" => "Hello World"}
          ]
        })

      assert changeset.valid?
    end

    test "requires suite_id" do
      changeset =
        TestCase.changeset(%TestCase{}, %{
          variable_values: %{},
          assertions: []
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).suite_id
    end

    test "requires variable_values" do
      suite = suite_fixture()

      changeset =
        TestCase.changeset(%TestCase{}, %{
          suite_id: suite.id,
          assertions: []
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).variable_values
    end

    test "requires assertions" do
      suite = suite_fixture()

      changeset =
        TestCase.changeset(%TestCase{}, %{
          suite_id: suite.id,
          variable_values: %{}
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).assertions
    end

    test "rejects assertions with unsupported types" do
      suite = suite_fixture()

      changeset =
        TestCase.changeset(%TestCase{}, %{
          suite_id: suite.id,
          variable_values: %{"name" => "John"},
          assertions: [%{"type" => "invalid_type", "value" => "Hello"}]
        })

      refute changeset.valid?

      assert {"Invalid assertion type at index 1: \"invalid_type\". Must be one of: contains, not_contains, regex, exact_match, json_field",
              []} =
               changeset.errors[:assertions]
    end
  end

  describe "associations" do
    test "has_many documents" do
      test_case = test_case_fixture()

      {:ok, doc} =
        %TestCaseDocument{}
        |> TestCaseDocument.changeset(%{
          test_case_id: test_case.id,
          filename: "test.pdf",
          content_type: "application/pdf",
          data: <<1, 2, 3>>,
          size_bytes: 100
        })
        |> Repo.insert()

      loaded = Repo.preload(test_case, :documents)
      assert [%TestCaseDocument{id: doc_id}] = loaded.documents
      assert doc_id == doc.id
    end
  end
end
