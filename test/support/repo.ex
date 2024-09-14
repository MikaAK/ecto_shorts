defmodule EctoShorts.Support.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :ecto_shorts,
    adapter: Ecto.Adapters.Postgres
end
