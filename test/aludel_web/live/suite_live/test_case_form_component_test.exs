defmodule Aludel.Web.SuiteLive.TestCaseFormComponentTest do
  use Aludel.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aludel.EvalsFixtures

  alias Aludel.Evals.TestCase

  describe "test case form component" do
    test "renders form with basic sections", %{conn: _conn} do
      suite = suite_fixture()
      test_case = %TestCase{suite_id: suite.id}

      html =
        render_component(Aludel.Web.SuiteLive.TestCaseFormComponent,
          id: "test-case-form",
          test_case: test_case,
          suite_id: suite.id
        )

      assert html =~ "Variables"
      assert html =~ "Assertions"
      assert html =~ "Documents"
      assert html =~ "Add Variable"
      assert html =~ "Add Assertion"
    end
  end
end
