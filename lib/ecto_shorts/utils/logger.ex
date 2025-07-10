defmodule EctoShorts.Utils.Logger do
  @moduledoc false
  require Logger

  @doc false
  @spec debug(identifier :: atom() | binary(), message :: binary()) :: :ok
  @spec debug(identifier :: atom() | binary(), message :: binary(), opts :: keyword()) :: :ok
  def debug(identifier, message, opts \\ []) do
    identifier |> format_message(message) |> Logger.debug(opts)
  end

  @doc false
  @spec info(identifier :: atom() | binary(), message :: binary()) :: :ok
  @spec info(identifier :: atom() | binary(), message :: binary(), opts :: keyword()) :: :ok
  def info(identifier, message, opts \\ []) do
    identifier |> format_message(message) |> Logger.info(opts)
  end

  @doc false
  @spec warning(identifier :: atom() | binary(), message :: binary()) :: :ok
  @spec warning(identifier :: atom() | binary(), message :: binary(), opts :: keyword()) :: :ok
  if Code.ensure_loaded?(:logger) and function_exported?(:logger, :warning, 2) do
    def warning(identifier, message, opts \\ []) do
      identifier |> format_message(message) |> Logger.warning(opts)
    end
  else
    def warning(identifier, message, opts \\ []) do
      identifier |> format_message(message) |> Logger.warn(opts)
    end
  end

  @doc false
  @spec error(identifier :: atom() | binary(), message :: binary()) :: :ok
  @spec error(identifier :: atom() | binary(), message :: binary(), opts :: keyword()) :: :ok
  def error(identifier, message, opts \\ []) do
    identifier |> format_message(message) |> Logger.error(opts)
  end

  defp format_message(identifier, message) do
    "[#{identifier(identifier)}] #{message}"
  end

  defp identifier(value) do
    value = to_string(value)

    if String.contains?(value, "Elixir.") do
      String.replace(value, "Elixir.", "")
    else
      value
    end
  end
end
