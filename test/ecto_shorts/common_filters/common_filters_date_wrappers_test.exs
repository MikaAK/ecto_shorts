defmodule EctoShorts.CommonFilters.DateWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  # `date:` wrapper shape: `%{field: %{comparator: %{date: %{fn: args}}}}`.
  # Both the field and the RHS are wrapped in `fragment("date(?)", ...)` before
  # the comparison is applied. Supported RHS shapes: `%{ago: ...}`,
  # `%{from_now: ...}`, `%{add: ...}`.
  describe "date wrappers" do
    test "rule statement 7: inserted_at equals ago 1 day using date wrapper" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) == fragment("date(?)", ago(^1, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{==: %{date: %{ago: %{count: 1, interval: "day"}}}}},
          []
        )

      assert_sql(expected, actual)
    end

    test "rule statement 8: inserted_at not equals from_now 1 day using date wrapper" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) != fragment("date(?)", from_now(^1, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{!=: %{date: %{from_now: %{count: 1, interval: "day"}}}}},
          []
        )

      assert_sql(expected, actual)
    end

    test "rule statement 10: inserted_at greater than from_now 1 day negated using date wrapper" do
      expected =
        from(p in Post,
          where:
            not (fragment("date(?)", p.inserted_at) > fragment("date(?)", from_now(^1, "day")))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{not: %{>: %{date: %{from_now: %{count: 1, interval: "day"}}}}}},
          []
        )

      assert_sql(expected, actual)
    end

    test "rule statement 11: inserted_at >= datetime_add 7 days using date wrapper" do
      expected =
        from(p in Post,
          where:
            fragment("date(?)", p.inserted_at) >=
              fragment("date(?)", datetime_add(p.inserted_at, ^7, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            inserted_at: %{
              >=: %{date: %{add: %{field: "inserted_at", count: 7, interval: "day"}}}
            }
          },
          []
        )

      assert_sql(expected, actual)
    end

    test "rule statement 12: inserted_at less than ago 1 month using date wrapper" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) < fragment("date(?)", ago(^1, "month"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{<: %{date: %{ago: %{count: 1, interval: "month"}}}}},
          []
        )

      assert_sql(expected, actual)
    end
  end
end
