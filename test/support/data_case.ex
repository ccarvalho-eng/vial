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

  using do
    quote do
      alias Aludel.Test.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Aludel.DataCase
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
  Sets up default Mox stub for LLM calls.
  This provides a fallback response for tests that don't set explicit expectations.
  """
  def setup_mox_stub do
    Mox.stub(Aludel.LLM.ReqLLMClientMock, :generate_text, fn _model, _prompt, _opts ->
      {:ok,
       %ReqLLM.Response{
         id: "test-id",
         model: "test-model",
         context: [
           %{role: "user", content: "test"},
           %{role: "assistant", content: [%{type: "text", text: "Test response"}]}
         ],
         message: %ReqLLM.Message{
           role: :assistant,
           content: [%{type: :text, text: "Test response"}]
         },
         finish_reason: :stop,
         usage: %{
           input_tokens: 10,
           output_tokens: 5,
           total_tokens: 15
         },
         error: nil,
         object: nil,
         provider_meta: %{},
         stream: nil,
         stream?: false
       }}
    end)
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
