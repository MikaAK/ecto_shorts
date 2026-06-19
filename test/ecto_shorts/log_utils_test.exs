defmodule EctoShorts.LogUtilsTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias EctoShorts.LogUtils

  # debug/2 and info/2 are gated by the configured Logger level (`:warning` in
  # test env), so whether they emit is Logger's concern. We only assert our
  # contract: the call returns :ok.
  describe "debug/2" do
    test "returns :ok" do
      assert LogUtils.debug("TestPrefix", "debug message") === :ok
    end
  end

  describe "info/2" do
    test "returns :ok" do
      assert LogUtils.info("TestPrefix", "info message") === :ok
    end
  end

  describe "warning/2" do
    test "prefixes the message and returns :ok" do
      log =
        capture_log(fn ->
          assert LogUtils.warning("TestPrefix", "warning message") === :ok
        end)

      assert log =~ "[TestPrefix] warning message"
    end
  end

  describe "error/2" do
    test "prefixes the message and returns :ok" do
      log =
        capture_log(fn ->
          assert LogUtils.error("TestPrefix", "error message") === :ok
        end)

      assert log =~ "[TestPrefix] error message"
    end
  end
end
