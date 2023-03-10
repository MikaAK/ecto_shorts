ExUnit.start()

Application.put_env(:ecto_shorts, :ecto_repos, [EctoShorts.Repo])

Application.put_env(:ecto_shorts, :sql_sandbox, true)

Application.put_env(:ecto_shorts, EctoShorts.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "",
  database: System.get_env("POSTGRES_DB") || "ecto_shorts",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
)
