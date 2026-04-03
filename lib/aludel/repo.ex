defmodule Aludel.Repo do
  @moduledoc """
  Central repository accessor for Aludel.

  Retrieves the configured Ecto repository from application
  environment.
  """

  @doc """
  Returns configured Ecto repository.

  Raises if repo is not configured in application environment.
  """
  @spec get() :: module()
  def get do
    Application.get_env(:aludel, :repo) ||
      raise """
      Aludel repo not configured.

      Add to your config:

          config :aludel, repo: YourApp.Repo
      """
  end
end
