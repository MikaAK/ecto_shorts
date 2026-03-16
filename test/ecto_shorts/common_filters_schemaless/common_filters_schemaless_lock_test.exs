defmodule EctoShorts.CommonFilters.SchemalessLockTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 lock shapes (schemaless)" do
    test "matches Ecto.Query for a root for_update alias lock" do
      expected = lock("posts", "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{lock: %{name: :for_update}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root for_share alias lock" do
      expected = lock("posts", "FOR SHARE")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{lock: %{name: :for_share}},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged for a direct raw string lock" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{lock: "FOR SHARE NOWAIT"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :lock value to be a map or keyword list with a :name key"
    end

    test "keeps the query unchanged for a direct raw function lock" do
      lock_fun = fn query -> from(p in query, lock: "FOR UPDATE") end
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{lock: lock_fun},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :lock value to be a map or keyword list with a :name key"
    end
  end
end
