defmodule Pollz.Repo do
  use Ecto.Repo,
    otp_app: :pollz,
    adapter: Ecto.Adapters.Postgres
end
