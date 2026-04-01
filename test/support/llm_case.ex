defmodule Aludel.LlmCase do
  @moduledoc """
  Helper functions for ReqLLM fixture-based testing.

  ## Usage

  Tests automatically use cached fixtures in replay mode (default).

  To record new fixtures:
      REQ_LLM_FIXTURES_MODE=record mix test

  Fixtures are stored in test/<path>/fixtures/ directory.
  """

  @doc """
  Returns the fixture path for a given test module and fixture name.

  ## Examples

      fixture_path(MyTest, "success")
      #=> "test/my_test/fixtures/success.json"
  """
  def fixture_path(test_module, fixture_name) do
    module_path =
      test_module
      |> Module.split()
      |> Enum.drop(1)
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join(["test", module_path, "fixtures", "#{fixture_name}.json"])
  end

  @doc """
  Check if we're in fixture recording mode.
  """
  def recording? do
    System.get_env("REQ_LLM_FIXTURES_MODE") == "record"
  end

  @doc """
  Ensure fixture directory exists for the given test module.
  """
  def ensure_fixture_dir(test_module) do
    fixture_dir =
      test_module
      |> Module.split()
      |> Enum.drop(1)
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()
      |> then(&Path.join(["test", &1, "fixtures"]))

    File.mkdir_p!(fixture_dir)
    fixture_dir
  end
end
