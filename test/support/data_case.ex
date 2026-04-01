defmodule Aludel.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Aludel.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Aludel.Interfaces.HttpClientMock

  using do
    quote do
      alias Aludel.Test.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Aludel.DataCase
      import Aludel.LlmStubs
      import Aludel.PromptsFixtures
      import Aludel.ProvidersFixtures
      import Aludel.EvalsFixtures
    end
  end

  setup tags do
    Aludel.DataCase.setup_sandbox(tags)
    Aludel.DataCase.setup_mox_stub()
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Aludel.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Sets up default Mox stub for HTTP client calls using LlmStubs.
  This provides a fallback response for tests that don't set explicit
  expectations.
  """
  def setup_mox_stub do
    Aludel.LlmStubs.setup_default_stub(HttpClientMock)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
