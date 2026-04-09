defmodule Aludel.Evals.TestCaseEditorTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals.TestCaseEditor

  describe "create_test_case/2" do
    test "creates a test case with prompt variables and default assertions" do
      suite = suite_fixture()
      prompt = prompt_fixture_with_version(%{template: "Hello {{ name }} from {{city}}"})

      assert {:ok, test_case} = TestCaseEditor.create_test_case(suite.id, prompt)
      assert test_case.variable_values == %{"name" => "", "city" => ""}
      assert test_case.assertions == [%{"type" => "contains", "value" => ""}]
    end

    test "creates a test case with empty variables when the prompt has no versions" do
      suite = suite_fixture()
      prompt = prompt_fixture()

      assert {:ok, test_case} = TestCaseEditor.create_test_case(suite.id, prompt)
      assert test_case.variable_values == %{}
      assert test_case.assertions == [%{"type" => "contains", "value" => ""}]
    end
  end

  describe "build_form_params/1" do
    test "builds editable form params for a test case" do
      test_case =
        test_case_fixture(%{
          variable_values: %{"name" => "Bob"},
          assertions: [%{"type" => "contains", "value" => "hello"}]
        })

      test_case_id = test_case.id

      assert %{
               "id" => ^test_case_id,
               "variable_values" => %{"name" => "Bob"},
               "assertions_json" => assertions_json,
               "assertions" => %{
                 "assertion_type_0" => "contains",
                 "assertion_value_0" => "hello"
               }
             } = TestCaseEditor.build_form_params(test_case)

      assert assertions_json =~ "\"value\": \"hello\""
    end
  end

  describe "update_test_case/3" do
    test "updates a test case from JSON assertions" do
      test_case = test_case_fixture(%{variable_values: %{"name" => "Bob"}})

      params = %{
        "variable_values" => %{"name" => "Alice"},
        "assertions_json" => ~s([{"type":"contains","value":"updated"}])
      }

      assert {:ok, updated_test_case} = TestCaseEditor.update_test_case(test_case, params, :json)
      assert updated_test_case.variable_values == %{"name" => "Alice"}
      assert updated_test_case.assertions == [%{"type" => "contains", "value" => "updated"}]
    end

    test "updates a test case from visual assertions" do
      test_case = test_case_fixture(%{variable_values: %{"name" => "Bob"}})

      params = %{
        "variable_values" => %{"name" => "Alice"},
        "assertions" => %{
          "assertion_type_0" => "contains",
          "assertion_value_0" => "updated"
        }
      }

      assert {:ok, updated_test_case} =
               TestCaseEditor.update_test_case(test_case, params, :visual)

      assert updated_test_case.variable_values == %{"name" => "Alice"}
      assert updated_test_case.assertions == [%{"type" => "contains", "value" => "updated"}]
    end

    test "returns assertion parsing errors without updating the test case" do
      test_case = test_case_fixture()

      assert {:error, "Invalid JSON syntax in assertions"} =
               TestCaseEditor.update_test_case(
                 test_case,
                 %{"assertions_json" => "{invalid json}"},
                 :json
               )
    end
  end
end
