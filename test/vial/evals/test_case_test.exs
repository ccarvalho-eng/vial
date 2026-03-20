defmodule Vial.Evals.TestCaseTest do
  use Vial.DataCase, async: true

  alias Vial.Evals.TestCase

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
  end
end
