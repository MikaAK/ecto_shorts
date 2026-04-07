defmodule EctoShorts.LoggerTest do
  use ExUnit.Case

  require Logger

  import ExUnit.CaptureLog

  describe "debug/2" do
    test "logs a debug message with prefix" do
      original_level = Elixir.Logger.level()

      Elixir.Logger.configure(level: :debug)

      log =
        capture_log(fn ->
          EctoShorts.Logger.debug("TestPrefix", "debug message")
        end)

      Elixir.Logger.configure(level: original_level)

      assert log =~ "[TestPrefix] debug message"
    end
  end

  describe "info/2" do
    test "logs an info message with prefix" do
      original_level = Elixir.Logger.level()

      Elixir.Logger.configure(level: :info)

      log =
        capture_log(fn ->
          EctoShorts.Logger.info("TestPrefix", "info message")
        end)

      Elixir.Logger.configure(level: original_level)

      assert log =~ "[TestPrefix] info message"
    end
  end

  describe "error/2" do
    test "logs an error message with prefix" do
      log =
        capture_log(fn ->
          EctoShorts.Logger.error("TestPrefix", "error message")
        end)

      assert log =~ "[TestPrefix] error message"
    end
  end
end
