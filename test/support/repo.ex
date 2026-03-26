defmodule Vial.Test.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :vial, adapter: Ecto.Adapters.Postgres
end
