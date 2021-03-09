defmodule Arevel.Repo do
  use Ecto.Repo,
    otp_app: :arevel,
    adapter: Ecto.Adapters.Postgres
end
