defmodule EctoShorts.CommonFilters.SchemalessDateWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "date wrappers (schemaless)" do
    test "inserted_at equals ago 1 day using date wrapper" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{==: %{date: %{ago: %{count: 1, interval: "day"}}}}},
          []
        )

      assert [%{expr: {:==, _, _}}] = actual.wheres
    end

    test "inserted_at not equals from_now 1 day using date wrapper" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{!=: %{date: %{from_now: %{count: 1, interval: "day"}}}}},
          []
        )

      assert [%{expr: {:!=, _, _}}] = actual.wheres
    end

    test "inserted_at greater than from_now 1 day negated using date wrapper" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{not: %{>: %{date: %{from_now: %{count: 1, interval: "day"}}}}}},
          []
        )

      assert [%{expr: {:not, _, _}}] = actual.wheres
    end

    test "inserted_at >= datetime_add 7 days using date wrapper" do
      expected =
        from(p in "posts",
          where:
            fragment("date(?)", p.inserted_at) >=
              fragment("date(?)", datetime_add(p.inserted_at, ^7, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{date: %{add: %{field: "inserted_at", count: 7, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "inserted_at less than ago 1 month using date wrapper" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{<: %{date: %{ago: %{count: 1, interval: "month"}}}}},
          []
        )

      assert [%{expr: {:<, _, _}}] = actual.wheres
    end
  end
end
