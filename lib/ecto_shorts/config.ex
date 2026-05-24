defmodule EctoShorts.Config do
  @moduledoc """
  Provides helper functions for reading the EctoShorts configuration from
  the application environment.

  ## Configuration

  All EctoShorts options are set under the `:ecto_shorts` application key in
  your config files:

      # config/config.exs
      config :ecto_shorts,
        repo: MyApp.Repo,
        replica: MyApp.Repo.Replica,
        dynamic_builder_module: EctoShorts.DynamicBuilders.Postgres,
        query_builder_module: MyApp.CustomQueryBuilder,
        query_provider_module: MyApp.QueryProvider,
        error_module: EctoShorts.Actions.Error,
        max_positional_bindings: 10

  | Key | Type | Default | Description |
  |---|---|---|---|
  | `:repo` | `module()` | `nil` | Primary `Ecto.Repo` for write operations |
  | `:replica` | `module()` | `nil` | Read replica repo; falls back to `:repo` when absent |
  | `:dynamic_builder_module` | `module()` | auto-detected | `EctoShorts.DynamicBuilder` implementation; auto-detected from the repo's database adapter when not set |
  | `:query_builder_module` | `module()` | `nil` | `EctoShorts.QueryBuilder` implementation used by `EctoShorts.CommonFilters` |
  | `:query_provider_module` | `module()` | `nil` | `EctoShorts.QueryProvider` implementation for named query expressions |
  | `:error_module` | `module()` | `EctoShorts.Actions.Error` | Module used by `EctoShorts.Actions` to build error responses |
  | `:max_positional_bindings` | `integer()` | `nil` | Maximum positional bindings allowed before EctoShorts raises |

  All options can also be overridden at runtime by passing the corresponding
  keyword option to any `EctoShorts.Actions` or `EctoShorts.CommonFilters`
  call. Runtime options take precedence over the application config.
  """

  @app :ecto_shorts

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:error_module` value from the `:ecto_shorts` application environment.

  Defaults to `EctoShorts.Actions.Error` when not set.

  ## Examples

      iex> EctoShorts.Config.error_module()
      EctoShorts.Actions.Error
  """
  @spec error_module :: module()
  def error_module do
    Application.get_env(@app, :error_module) || EctoShorts.Actions.Error
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:repo` value from the `:ecto_shorts` application environment.

  Defaults to `nil` if not set.

  ## Examples

      iex> EctoShorts.Config.repo()
      EctoShorts.Repo
  """
  @spec repo :: module() | nil
  def repo do
    Application.get_env(@app, :repo)
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:replica` value from the `:ecto_shorts` application environment.

  Defaults to `nil` if not set.

  ## Examples

      iex> EctoShorts.Config.replica()
      nil
  """
  @spec replica :: module() | nil
  def replica do
    Application.get_env(@app, :replica)
  end

  @doc since: "3.0.0"
  @doc """
  Returns the `Ecto.Repo` module to use.

  Looks for the `:repo` option first, falling back to the configured value in the
  `:ecto_shorts` application environment.

  Raises if no repo is found.

  ## Examples

      iex> EctoShorts.Config.repo!()
      EctoShorts.Repo

      iex> EctoShorts.Config.repo!(repo: MyApp.Repo)
      MyApp.Repo
  """
  @spec repo!(opts :: keyword()) :: module()
  @spec repo! :: module()
  def repo!(opts \\ []) do
    with nil <- Keyword.get(opts, :repo, repo()) do
      raise """
      EctoShorts repo not configured!

      Expected one of the following:

        * Pass the `:repo` option at runtime:

          ```
          EctoShorts.Actions.all(MyApp.Schema, %{id: [1, 2, 3]}, repo: MyApp.Repo)
          ```

        * Configure a default repo in your application config:

          ```
          # config/config.exs
          import Config

          config :ecto_shorts, :repo, MyApp.Repo
          ```
      """
    end
  end

  @doc since: "3.0.0"
  @doc """
  Returns the `Ecto.Repo` module to use for read (replica) operations.

  Checks the `:replica` option first, then falls back to the `:replica`
  or `:repo` key in the `:ecto_shorts` application configuration.

  Raises if no suitable repo is found.

  ## Examples

      iex> EctoShorts.Config.replica!()
      EctoShorts.Repo

      iex> EctoShorts.Config.replica!(replica: MyApp.Repo.Replica)
      MyApp.Repo.Replica
  """
  @spec replica!(opts :: keyword()) :: module()
  @spec replica! :: module()
  def replica!(opts \\ []) do
    with nil <- Keyword.get(opts, :replica, replica()),
         nil <- Keyword.get(opts, :repo, repo()) do
      raise """
      EctoShorts replica and repo not configured!

      Expected one of the following to be set:

        * Pass the `:replica` option at runtime:

          ```
          EctoShorts.Actions.all(MyApp.Schema, %{id: [1, 2, 3]}, replica: MyApp.Repo.Replica)
          ```

        * Configure a replica in your application config:

          ```
          # config/config.exs
          import Config

          config :ecto_shorts, :replica, MyApp.Repo.Replica
          ```

        * Pass the `:repo` option at runtime (used as a fallback if no replica is set):

          ```
          EctoShorts.Actions.all(MyApp.Schema, %{id: [1, 2, 3]}, repo: MyApp.Repo)
          ```

        * Configure a default repo in your application config:

          ```
          # config/config.exs
          import Config

          config :ecto_shorts, :repo, MyApp.Repo
          ```
      """
    end
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:dynamic_builder_module` value from the
  application environment. Defaults to `nil`.

  ## Examples

      iex> EctoShorts.Config.dynamic_builder_module()
      nil
  """
  @spec dynamic_builder_module :: module() | nil
  def dynamic_builder_module do
    Application.get_env(@app, :dynamic_builder_module)
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:query_builder_module` value from the
  application environment. Defaults to `nil`.

  ## Examples

      iex> EctoShorts.Config.query_builder_module()
      nil
  """
  @spec query_builder_module :: module() | nil
  def query_builder_module do
    Application.get_env(@app, :query_builder_module)
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:query_provider_module` value from the
  application environment. Defaults to `nil`.

  ## Examples

      iex> EctoShorts.Config.query_provider_module()
      nil
  """
  @spec query_provider_module :: module() | nil
  def query_provider_module do
    Application.get_env(@app, :query_provider_module)
  end

  @doc since: "3.0.0"
  @doc """
  Returns the configured `:max_positional_bindings` value from the
  application environment. Defaults to `nil`.

  ## Examples

      iex> EctoShorts.Config.max_positional_bindings()
      nil
  """
  @spec max_positional_bindings :: integer() | nil
  def max_positional_bindings do
    Application.get_env(@app, :max_positional_bindings)
  end
end
