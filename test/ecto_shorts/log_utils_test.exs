defmodule EctoShorts.LogUtilsTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias EctoShorts.LogUtils

  # debug/2 and info/2 are gated by the configured Logger level (`:warning` in
  # test env), so whether they emit is Logger's concern. We only assert our
  # contract: the call returns :ok.
  describe "debug/2" do
    test "returns :ok" do
      assert :ok = LogUtils.debug("TestPrefix", "debug message")
    end
  end

  describe "info/2" do
    test "returns :ok" do
      assert :ok = LogUtils.info("TestPrefix", "info message")
    end
  end

  describe "warning/2" do
    test "prefixes the message and returns :ok" do
      log =
        capture_log(fn ->
          assert :ok = LogUtils.warning("TestPrefix", "warning message")
        end)

      assert log =~ "[TestPrefix] warning message"
    end
  end

  describe "error/2" do
    test "prefixes the message and returns :ok" do
      log =
        capture_log(fn ->
          assert :ok = LogUtils.error("TestPrefix", "error message")
        end)

      assert log =~ "[TestPrefix] error message"
    end
  end
end
