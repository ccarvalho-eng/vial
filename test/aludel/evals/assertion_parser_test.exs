defmodule Aludel.Evals.AssertionParserTest do
  use ExUnit.Case, async: true

  alias Aludel.Evals.AssertionParser

  describe "parse/2" do
    test "parses JSON assertions" do
      params = %{
        "assertions_json" => ~s([{"type":"contains","value":"hello"}])
      }

      assert {:ok, [%{"type" => "contains", "value" => "hello"}]} =
               AssertionParser.parse(:json, params)
    end

    test "rejects invalid JSON assertions" do
      params = %{"assertions_json" => "{invalid json}"}

      assert {:error, "Invalid JSON syntax in assertions"} =
               AssertionParser.parse(:json, params)
    end

    test "rejects JSON assertions when the payload is not a list" do
      params = %{"assertions_json" => ~s({"type":"contains","value":"hello"})}

      assert {:error, "Invalid JSON: assertions must be a list"} =
               AssertionParser.parse(:json, params)
    end

    test "rejects JSON assertions with an invalid type" do
      params = %{
        "assertions_json" => ~s([{"type":"invalid_type","value":"hello"}])
      }

      assert {:error, message} = AssertionParser.parse(:json, params)
      assert message =~ "Invalid assertion type at index 1"
    end

    test "parses visual assertions" do
      params = %{
        "assertions" => %{
          "assertion_type_0" => "contains",
          "assertion_value_0" => "hello",
          "assertion_type_1" => "json_field",
          "assertion_field_1" => "sentiment",
          "assertion_expected_1" => "positive"
        }
      }

      assert {:ok,
              [
                %{"type" => "contains", "value" => "hello"},
                %{
                  "type" => "json_field",
                  "field" => "sentiment",
                  "expected" => "positive"
                }
              ]} = AssertionParser.parse(:visual, params)
    end

    test "rejects visual assertions with invalid indices" do
      params = %{
        "assertions" => %{
          "assertion_type_abc" => "contains",
          "assertion_value_abc" => "hello"
        }
      }

      assert {:error, "Invalid assertion index: abc"} =
               AssertionParser.parse(:visual, params)
    end

    test "rejects json_field assertions missing expected keys" do
      params = %{
        "assertions_json" => ~s([{"type":"json_field"}])
      }

      assert {:error, message} = AssertionParser.parse(:json, params)
      assert message =~ "json_field type requires 'field' and 'expected' fields"
    end
  end

  describe "build_form_params/1" do
    test "builds JSON and visual params from assertions" do
      assertions = [%{"type" => "contains", "value" => "hello"}]

      assert %{
               "assertions_json" => assertions_json,
               "assertions" => %{
                 "assertion_type_0" => "contains",
                 "assertion_value_0" => "hello"
               }
             } = AssertionParser.build_form_params(assertions)

      assert assertions_json =~ "\"type\": \"contains\""
    end
  end
end
