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
  @spec replica :: Ecto.Repo.t() | nil
  def replica do
    Application.get_env(@app, :replica)
  end

  @doc """
  Returns a `Ecto.Repo` module.

  Raises if the repo is not configured and the option `:repo` is not set.

  ### Examples

      iex> EctoShorts.Config.repo!()
      EctoShorts.Support.Repo

      iex> EctoShorts.Config.repo!(repo: YourApp.Repo)
      YourApp.Repo
  """
  @spec repo!(keyword()) :: Ecto.Repo.t()
  @spec repo! :: Ecto.Repo.t()
  def repo!(opts \\ []) do
    with nil <- Keyword.get(opts, :repo, repo()) do
      raise ArgumentError, """
      EctoShorts must be configured with a repo.

      To fix this error you can do one of the following:

      1. Configure the repo:

      ```
      config :ecto_shorts, :repo, YourApp.Repo
      ```

      2. Pass in the `:repo` option:

      ```
      [repo: YourApp.Repo]
      ```
      """
    end
  end

  @doc """
  Returns a `Ecto.Repo` module.

  This function attempts to retrieve a repo from the `:replica` option
  and will fallback to returning the value from the `:repo` option or
  the configured repo if the option `:replica` is not set.

  Raises if no repo is found.

  ### Examples

      iex> EctoShorts.Config.replica!()
      EctoShorts.Support.Repo

      iex> EctoShorts.Config.replica!(replica: YourApp.Repo.Replica)
      YourApp.Repo.Replica
  """
  @spec replica!(keyword()) :: Ecto.Repo.t()
  @spec replica! :: Ecto.Repo.t()
  def replica!(opts \\ []) do
    with nil <- Keyword.get(opts, :replica, replica()) do
      repo!(opts)
    end
  end
end
