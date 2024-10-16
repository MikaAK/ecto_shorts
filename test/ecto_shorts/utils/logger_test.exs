defmodule EctoShorts.Utils.LoggerTest do
  use ExUnit.Case
  doctest EctoShorts.Utils.Logger

  import ExUnit.CaptureLog

  @logger_prefix "EctoShorts.Utils.LoggerTest"

  test "debug" do
    assert capture_log([level: :debug], fn ->
      EctoShorts.Utils.Logger.debug(@logger_prefix, "debug")
    end) =~ "[EctoShorts.Utils.LoggerTest] debug"
  end

  test "info" do
    assert capture_log([level: :info], fn ->
      EctoShorts.Utils.Logger.info(@logger_prefix, "info")
    end) =~ "[EctoShorts.Utils.LoggerTest] info"
  end

  test "warning" do
    assert capture_log([level: :warning], fn ->
      EctoShorts.Utils.Logger.warning(@logger_prefix, "warning")
    end) =~ "[EctoShorts.Utils.LoggerTest] warning"
  end

  test "error" do
    assert capture_log([level: :error], fn ->
      EctoShorts.Utils.Logger.error(@logger_prefix, "error")
    end) =~ "[EctoShorts.Utils.LoggerTest] error"
  end
end
