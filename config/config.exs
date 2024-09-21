# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :ecto_shorts,
  repo: nil,
  replica: nil,
  error_module: EctoShorts.Actions.Error

if Mix.env() === :test do
  config :ecto_shorts, ecto_repos: [EctoShorts.Support.Repo]
  config :ecto_shorts, repo: EctoShorts.Support.Repo
  config :ecto_shorts, :sql_sandbox, true
  config :ecto_shorts, EctoShorts.Support.Repo,
    username: "postgres",
    database: "ecto_shorts_test",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    stacktrace: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end
