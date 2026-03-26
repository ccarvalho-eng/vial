defmodule Aludel.Evals.SuiteTest do
  use Aludel.DataCase, async: true

  alias Aludel.Evals.Suite

  describe "changeset/2" do
    test "valid changeset with all fields" do
      prompt = prompt_fixture()

      changeset =
        Suite.changeset(%Suite{}, %{
          name: "Test Suite",
          prompt_id: prompt.id
        })

      assert changeset.valid?
    end

    test "requires name" do
      prompt = prompt_fixture()

      changeset = Suite.changeset(%Suite{}, %{prompt_id: prompt.id})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires prompt_id" do
      changeset = Suite.changeset(%Suite{}, %{name: "Test"})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).prompt_id
    end
  end
end
