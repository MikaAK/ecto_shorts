defmodule EctoShorts.Config do
  @moduledoc """
  Configuration utilities for EctoShorts.
  
  This module provides functions to access and validate configuration settings
  for the EctoShorts library, particularly for repository access.
  """

  @app :ecto_shorts

  @doc """
  Returns the configured repository module for EctoShorts.
  
  Retrieves the value set for the `:repo` key in the `:ecto_shorts` application
  configuration. Returns `nil` if no repository is configured.
  
  ## Examples
  
      iex> EctoShorts.Config.repo()
      MyApp.Repo
      
      # When no repo is configured
      iex> EctoShorts.Config.repo()
      nil
  """
  @spec repo :: Ecto.Repo.t() | nil
  def repo do
    Application.get_env(@app, :repo)
  end

  @doc """
  Returns the configured read replica repository module for EctoShorts.
  
  Retrieves the value set for the `:replica` key in the `:ecto_shorts` application
  configuration. Returns `nil` if no read replica is configured.
  
  Read replicas are used for read operations when specified, allowing you to
  distribute database load between primary and replica databases.
  
  ## Examples
  
      iex> EctoShorts.Config.replica()
      MyApp.ReplicaRepo
      
      # When no replica is configured
      iex> EctoShorts.Config.replica()
      nil
  """
  @doc since: "2.5.0"
  @spec replica :: Ecto.Repo.t() | nil
  def replica do
    Application.get_env(@app, :replica)
  end

  @doc """
  Returns a repository module, raising an error if none is available.
  
  This function attempts to retrieve a repository in the following order:
  
  1. From the `:repo` option in the provided keyword list
  2. From the application configuration
  
  ## Parameters
  
  * `opts` - Optional keyword list containing configuration overrides
  
  ## Returns
  
  An `Ecto.Repo` module
  
  ## Raises
  
  `ArgumentError` if no repository is found in either the options or configuration
  
  ## Examples
  
      # Using the configured repo
      iex> EctoShorts.Config.repo!()
      MyApp.Repo
  
      # Overriding with a specific repo
      iex> EctoShorts.Config.repo!(repo: MyApp.CustomRepo)
      MyApp.CustomRepo
  
      # When no repo is configured or provided
      iex> EctoShorts.Config.repo!()
      ** (ArgumentError) EctoShorts repo not configured!
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
  Returns a read replica repository module, falling back to primary repo if needed.
  
  This function attempts to retrieve a repository in the following order:
  
  1. From the `:replica` option in the provided keyword list
  2. From the `:replica` in the application configuration
  3. From the `:repo` option in the provided keyword list
  4. From the `:repo` in the application configuration
  
  ## Parameters
  
  * `opts` - Optional keyword list containing configuration overrides
  
  ## Returns
  
  An `Ecto.Repo` module suitable for read operations
  
  ## Raises
  
  `ArgumentError` if no repository is found in any of the possible locations
  
  ## Examples
  
      # Using the configured replica
      iex> EctoShorts.Config.replica!()
      MyApp.ReplicaRepo
  
      # Overriding with a specific replica
      iex> EctoShorts.Config.replica!(replica: MyApp.CustomReplicaRepo)
      MyApp.CustomReplicaRepo
      
      # Falling back to primary repo when no replica is configured
      iex> EctoShorts.Config.replica!()
      MyApp.Repo
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
