defmodule EctoShorts.CommonFilters.DatetimeWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  # `datetime:` wrapper shape: `%{field: %{comparator: %{datetime: %{fn: args}}}}`.
  # The RHS is replaced with the Ecto datetime function before the comparison is
  # applied. Supported RHS shapes: `%{add: ...}` (`datetime_add`), `%{ago: ...}`
  # (`ago`), `%{from_now: ...}` (`from_now`). The field side is not wrapped.
  describe "convert_params_to_filter/3 datetime wrappers" do
    test "matches records using datetime_add before comparison" do
      expected = from(p in Post, where: p.inserted_at >= datetime_add(p.inserted_at, ^1, "day"))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            inserted_at: %{
              >=: %{datetime: %{add: %{field: "inserted_at", count: 1, interval: "day"}}}
            }
          },
          []
        )

      assert_sql(expected, actual)
    end

    test "matches records using ago before comparison" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{>: %{datetime: %{ago: %{count: 1, interval: "day"}}}}},
          []
        )

      expected = from(p in Post, where: p.inserted_at > ago(^1, "day"))

      assert_sql(expected, actual)
    end

    test "matches records using from_now before comparison" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{inserted_at: %{>: %{datetime: %{from_now: %{count: 1, interval: "day"}}}}},
          []
        )

      expected = from(p in Post, where: p.inserted_at > from_now(^1, "day"))

      assert_sql(expected, actual)
    end

    test "excludes records using negated datetime_add comparison" do
      expected =
        from(p in Post, where: not (p.inserted_at >= datetime_add(p.inserted_at, ^1, "day")))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            inserted_at: %{
              not: %{>=: %{datetime: %{add: %{field: "inserted_at", count: 1, interval: "day"}}}}
            }
          },
          []
        )

      assert_sql(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 datetime from_now comparisons" do
    test "matches records using datetime from_now comparison" do
      expected = from(p in Post, where: p.published_at > from_now(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{>: %{datetime: %{from_now: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated datetime from_now comparison" do
      expected = from(p in Post, where: not (p.published_at > from_now(^1, "month")))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{>: %{datetime: %{from_now: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using date from_now comparison" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.published_at) > fragment("date(?)", from_now(^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{>: %{date: %{from_now: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated date from_now comparison" do
      expected =
        from(p in Post,
          where:
            not (fragment("date(?)", p.published_at) > fragment("date(?)", from_now(^1, "month")))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{>: %{date: %{from_now: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "convert_params_to_filter/3 datetime add comparisons" do
    test "matches records using datetime add comparison" do
      expected =
        from(p in Post,
          where: p.published_at > datetime_add(p.published_at, ^1, "month")
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            published_at: %{
              >: %{datetime: %{add: [field: :published_at, count: 1, interval: "month"]}}
            }
          },
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated datetime add comparison" do
      expected =
        from(p in Post,
          where: not (p.published_at > datetime_add(p.published_at, ^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            published_at: %{
              not: %{>: %{datetime: %{add: [field: :published_at, count: 1, interval: "month"]}}}
            }
          },
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using date add comparison" do
      expected =
        from(p in Post,
          where:
            fragment("date(?)", p.published_at) >
              fragment("date(?)", datetime_add(p.published_at, ^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            published_at: %{
              >: %{date: %{add: [field: :published_at, count: 1, interval: "month"]}}
            }
          },
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated date add comparison" do
      expected =
        from(p in Post,
          where:
            not (fragment("date(?)", p.published_at) >
                   fragment("date(?)", datetime_add(p.published_at, ^1, "month")))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            published_at: %{
              not: %{>: %{date: %{add: [field: :published_at, count: 1, interval: "month"]}}}
            }
          },
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "convert_params_to_filter/3 datetime negated != and <= variants" do
    test "matches records using negated datetime != (produces ==)" do
      expected = from(p in Post, where: p.published_at == ago(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{!=: %{datetime: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated datetime >= comparison" do
      expected = from(p in Post, where: not (p.published_at >= ago(^1, "month")))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{>=: %{datetime: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated datetime < comparison" do
      expected = from(p in Post, where: not (p.published_at < ago(^1, "month")))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{<: %{datetime: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated datetime <= comparison" do
      expected = from(p in Post, where: not (p.published_at <= ago(^1, "month")))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{<=: %{datetime: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using datetime != comparison (plain)" do
      expected = from(p in Post, where: p.published_at != ago(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{!=: %{datetime: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using datetime >= comparison (plain)" do
      expected = from(p in Post, where: p.published_at >= ago(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{>=: %{datetime: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using datetime < comparison (plain)" do
      expected = from(p in Post, where: p.published_at < ago(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{<: %{datetime: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using datetime <= comparison (plain)" do
      expected = from(p in Post, where: p.published_at <= ago(^1, "month"))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{<=: %{datetime: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end
end
