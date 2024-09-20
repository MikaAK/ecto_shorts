defmodule EctoShorts.Support.TestRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :ecto_shorts,
    adapter: Ecto.Adapters.Postgres

  alias Ecto.Adapters.SQL.Sandbox
  alias EctoShorts.Support.TestRepo

  def with_shared_connection(func) do
    with :ok <- Sandbox.checkout(TestRepo),
      :ok <- Sandbox.mode(TestRepo, {:shared, self()}) do
      func.()
    end
  end
end
