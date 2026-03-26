defmodule Aludel.Test.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :aludel, adapter: Ecto.Adapters.Postgres
end
