# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :ecto_shorts, repo: nil, error_module: EctoShorts.Actions.Error

if Mix.env() == :test do
  config :ecto_shorts, repo: EctoShorts.Repo

  config :ecto_shorts, ecto_repos: [EctoShorts.Repo]

  config :ecto_shorts, :sql_sandbox, true

  config :ecto_shorts, EctoShorts.Repo,
    username: System.get_env("POSTGRES_USER") || "postgres",
    password: System.get_env("POSTGRES_PASSWORD") || "",
    database: System.get_env("POSTGRES_DB") || "ecto_shorts",
    hostname: System.get_env("POSTGRES_HOST") || "localhost",
    show_sensitive_data_on_connection_error: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end
