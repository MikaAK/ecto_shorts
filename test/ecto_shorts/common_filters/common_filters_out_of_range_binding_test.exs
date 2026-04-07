defmodule EctoShorts.CommonFilters.OutOfRangeBindingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  # The default max_positional_bindings is 10.
  # Position 11 is one beyond the default max.
  @out_of_range_position 11

  describe "warns and skips out-of-range :at field filters" do
    test "field filter at out-of-range position logs warning and returns query unchanged" do
      base_query =
        from(p in Post,
          join: c in assoc(p, :comments)
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              base_query,
              %{at: %{@out_of_range_position => %{title: "hello"}}},
              []
            )

          assert_query(base_query, actual)
        end)

      assert log =~ "out of range"
      assert log =~ "#{@out_of_range_position}"
    end

    test "position zero logs warning and returns query unchanged" do
      base_query = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              base_query,
              %{at: %{0 => %{title: "hello"}}},
              []
            )

          assert_query(base_query, actual)
        end)

      assert log =~ "out of range"
    end

    test "negative position logs warning and returns query unchanged" do
      base_query = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              base_query,
              %{at: %{-1 => %{title: "hello"}}},
              []
            )

          assert_query(base_query, actual)
        end)

      assert log =~ "out of range"
    end
  end

  describe "warns and skips out-of-range :at structural filters" do
    test "having at out-of-range position logs warning and returns query unchanged" do
      base_query =
        from(p in Post,
          join: c in assoc(p, :comments),
          group_by: p.id
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              base_query,
              %{at: %{@out_of_range_position => %{having: %{views: %{avg: %{>: 100}}}}}},
              []
            )

          assert_query(base_query, actual)
        end)

      assert log =~ "out of range"
      assert log =~ "#{@out_of_range_position}"
    end

    test "order_by at out-of-range position logs warning and returns query unchanged" do
      base_query =
        from(p in Post,
          join: c in assoc(p, :comments)
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              base_query,
              %{at: %{@out_of_range_position => %{order_by: :title}}},
              []
            )

          assert_query(base_query, actual)
        end)

      assert log =~ "out of range"
      assert log =~ "#{@out_of_range_position}"
    end
  end

  describe "still applies in-range :at positions" do
    test "position within max applies the filter normally" do
      base_query =
        from(p in Post,
          join: c in assoc(p, :comments)
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          where: c.published == ^true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{2 => %{published: true}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
