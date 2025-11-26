defmodule Churchapp.Repo do
  use Ecto.Repo,
    otp_app: :churchapp,
    adapter: Ecto.Adapters.Postgres
end
