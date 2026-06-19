defmodule EctoShorts.CommonFilters.OutOfRangeBindingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :out_of_range_binding

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  # The default max_positional_bindings is 10.
  # Position 11 is one beyond the default max.
  @out_of_range_position 11

  describe "raises on out-of-range :at field filters (D-RAISE)" do
    test "field filter at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments))

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{title: "hello"}}},
          []
        )
      end
    end

    test "position zero raises" do
      base_query = from(p in Post)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{0 => %{title: "hello"}}},
          []
        )
      end
    end

    test "negative position raises" do
      base_query = from(p in Post)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{-1 => %{title: "hello"}}},
          []
        )
      end
    end
  end

  describe "raises on out-of-range :at structural filters (D-RAISE)" do
    test "having at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments), group_by: p.id)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{having: %{views: %{avg: %{>: 100}}}}}},
          []
        )
      end
    end

    test "order_by at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments))

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{order_by: :title}}},
          []
        )
      end
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
