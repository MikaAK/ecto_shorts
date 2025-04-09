defmodule EctoShorts.Config do
  @moduledoc false

  @app :ecto_shorts

  @doc """
  Returns the value of `ecto_shorts` config key `:repo`.

  ### Examples

      iex> EctoShorts.Config.repo()
      EctoShorts.Support.Repo
  """
  @spec repo :: Ecto.Repo.t() | nil
  def repo do
    Application.get_env(@app, :repo)
  end

  @doc """
  Returns the value of `ecto_shorts` config key `:replica`.

  ### Examples

      iex> EctoShorts.Config.replica()
      nil
  """
  @doc since: "2.5.0"
  @spec replica :: Ecto.Repo.t() | nil
  def replica do
    Application.get_env(@app, :replica)
  end

  @doc """
  Returns a `Ecto.Repo` module.

  Raises if the key `:repo` is not specified in configuration
  and the option `:repo` is not specified at runtime.

  ### Examples

      iex> EctoShorts.Config.repo!()
      EctoShorts.Support.Repo

      iex> EctoShorts.Config.repo!(repo: YourApp.Repo)
      YourApp.Repo
  """
  @doc since: "2.5.0"
  @spec repo!(opts :: keyword()) :: Ecto.Repo.t()
  @spec repo! :: Ecto.Repo.t()
  def repo!(opts \\ []) do
    with nil <- Keyword.get(opts, :repo, repo()) do
      raise ArgumentError, """
      EctoShorts repo not configured!

      Expected one of the following:

      * The option `:repo` is specified at runtime.

        ```
        EctoShorts.Actions.all(YourApp.Schema, %{id: [1, 2, 3]}, repo: YourApp.Repo)
        ```

      * The option `:repo` is set in configuration.

        ```
        # config.exs
        import Config

        config :ecto_shorts, :repo, YourApp.Repo
        ```
      """
    end
  end

  @doc """
  Returns a `Ecto.Repo` module.

  Raises if the key `:replica` and `:repo` is not specified in
  configuration and the option `:replica` and `:repo` is not
  specified at runtime.

  ### Examples

      iex> EctoShorts.Config.replica!()
      EctoShorts.Support.Repo

      iex> EctoShorts.Config.replica!(replica: YourApp.Repo.Replica)
      YourApp.Repo.Replica
  """
  @doc since: "2.5.0"
  @spec replica!(opts :: keyword()) :: Ecto.Repo.t()
  @spec replica! :: Ecto.Repo.t()
  def replica!(opts \\ []) do
    with nil <- Keyword.get(opts, :replica, replica()),
      nil <- Keyword.get(opts, :repo, repo()) do
      raise ArgumentError, """
      EctoShorts replica and repo not configured!

      Expected one of the following:

      * The option `:replica` is specified at runtime.

        ```
        EctoShorts.Actions.all(YourApp.Schema, %{id: [1, 2, 3]}, replica: YourApp.Repo.Replica)
        ```

      * The option `:replica` is set in configuration.

        ```
        # config.exs
        import Config

        config :ecto_shorts, :replica, YourApp.Repo.Replica
        ```

      * The option `:repo` is specified at runtime.

        ```
        EctoShorts.Actions.all(YourApp.Schema, %{id: [1, 2, 3]}, repo: YourApp.Repo)
        ```

      * The option `:repo` is set in configuration.

        ```
        # config.exs
        import Config

        config :ecto_shorts, :repo, YourApp.Repo
        ```
      """
    end
  end
end
