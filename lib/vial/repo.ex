defmodule Vial.Repo do
  use Ecto.Repo,
    otp_app: :vial,
    adapter: Ecto.Adapters.Postgres
end
