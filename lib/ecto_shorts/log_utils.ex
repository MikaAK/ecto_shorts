defmodule EctoShorts.LogUtils do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Prefixed logging wrapper used internally by EctoShorts modules.

  Each log function prepends a `[prefix]` tag to the message before
  delegating to Elixir's `Logger`.
  """
  require Logger

  @doc """
  Logs a :debug level message with a prefix.

  ## Examples

      iex> EctoShorts.LogUtils.debug("MyApp.SomeModule", "hello")
  """
  @spec debug(prefix :: String.t(), message :: String.t()) :: :ok
  def debug(prefix, message) do
    message
    |> format_message(prefix)
    |> Logger.debug()
  end

  @doc """
  Logs a :info level message with a prefix.

  ## Examples

      iex> EctoShorts.LogUtils.info("MyApp.SomeModule", "hello")
  """
  @spec info(prefix :: String.t(), message :: String.t()) :: :ok
  def info(prefix, message) do
    message
    |> format_message(prefix)
    |> Logger.info()
  end

  @doc """
  Logs a :error level message with a prefix.

  ## Examples

      iex> EctoShorts.LogUtils.error("MyApp.SomeModule", "hello")
  """
  @spec error(prefix :: String.t(), message :: String.t()) :: :ok
  def error(prefix, message) do
    message
    |> format_message(prefix)
    |> Logger.error()
  end

  @doc """
  Logs a :warning level message with a prefix.

  ## Examples

      iex> EctoShorts.LogUtils.warning("MyApp.SomeModule", "hello")
  """
  @spec warning(prefix :: String.t(), message :: String.t()) :: :ok
  def warning(prefix, message) do
    message
    |> format_message(prefix)
    |> Logger.warning()
  end

  defp format_message(message, prefix) do
    "[#{prefix}] " <> message
  end
end
