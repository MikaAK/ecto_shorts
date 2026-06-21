# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :ecto_shorts, repo: EctoShorts.Repo

if Mix.env() === :test do
  config :logger, level: :warning

  config :ecto_shorts, :sql_sandbox, true
  config :ecto_shorts, ecto_repos: [EctoShorts.Repo]

  config :ecto_shorts,
    hints: [test_index: ["USE INDEX(test_index)"]]

  config :ecto_shorts, EctoShorts.Repo,
    username: "postgres",
    password: System.get_env("POSTGRES_PASSWORD") || "postgres",
    database: "ecto_shorts_test",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    stacktrace: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 20
else
  config :logger, level: :debug

  config :ecto_shorts,
    repo: nil,
    replica: nil,
    error_module: EctoShorts.Actions.Error,
    dynamic_builder: EctoShorts.DynamicBuilders.Postgres,
    max_positional_bindings: 10,
    query_provider: nil,
    hints: []

  config :ecto_shorts, EctoShorts.Repo,
    username: "postgres",
    database: "ecto_shorts_dev",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: false,
    log: :error,
    stacktrace: false,
    pool_size: 20
end
