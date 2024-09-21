defmodule EctoShorts.Utils.Logger do
  @moduledoc false
  require Logger

  @doc false
  @spec debug(
    identifier :: binary(),
    message :: binary(),
    options :: keyword()
  ) :: :ok
  def debug(identifier, message, options \\ []) do
    identifier
    |> format_message(message)
    |> Logger.debug(options)
  end

  @doc false
  @spec info(
    identifier :: binary(),
    message :: binary(),
    options :: keyword()
  ) :: :ok
  def info(identifier, message, options \\ []) do
    identifier
    |> format_message(message)
    |> Logger.info(options)
  end

  @doc false
  @spec warning(
    identifier :: binary(),
    message :: binary(),
    options :: keyword()
  ) :: :ok
  if EctoShorts.Utils.meets_version_requirement?(:logger, "1.11.0") do
    def warning(identifier, message, options \\ []) do
      identifier
      |> format_message(message)
      |> Logger.warning(options)
    end
  else
    def warning(identifier, message, options \\ []) do
      identifier
      |> format_message(message)
      |> Logger.warn(options)
    end
  end

  @doc false
  @spec error(
    identifier :: binary(),
    message :: binary(),
    options :: keyword()
  ) :: :ok
  def error(identifier, message, options \\ []) do
    identifier
    |> format_message(message)
    |> Logger.error(options)
  end

  defp format_message(identifier, message) do
    "[#{identifier}] #{message}"
  end
end
