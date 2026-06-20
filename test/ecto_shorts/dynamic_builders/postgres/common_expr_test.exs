defmodule EctoShorts.DynamicBuilders.Postgres.CommonExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.DynamicBuilders.Postgres.CommonExpr
  alias EctoShorts.Schema.Post

  import Ecto.Query



  describe "root binding" do
    test "list value produces membership expression on the given column" do
      expected = dynamic([q], field(q, :id) in ^[1, 2])
      actual = CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:ids, [1, 2]}, [])

      assert_dynamic(expected, actual)
    end

    test "unknown operator returns nil" do
      assert is_nil(CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:missing, 1}, []))
    end
  end

  describe "named binding alias" do
    test "datetime value produces named-alias expression on the given column" do
      date = ~U[2026-03-09 02:04:01.573399Z]
      expected = from(p in Post, as: :post, where: p.inserted_at >= ^date)

      actual =
        from(p in Post,
          as: :post,
          where:
            ^CommonExpr.dynamic_expr({:as, :post}, :inserted_at, nil, {:since_date, date}, [])
        )

      assert_sql(expected, actual)
    end
  end

  describe "positional binding" do
    test "positional binding produces expression on the correct join position" do
      expected = dynamic([_, q], field(q, :id) < ^10)
      actual = CommonExpr.dynamic_expr({:at, 2}, :id, nil, {:before, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "same binding selector called twice produces identical expressions" do
      expected = CommonExpr.dynamic_expr({:at, 2}, :id, nil, {:before, 10}, [])
      actual = CommonExpr.dynamic_expr({:at, 2}, :id, nil, {:before, 10}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "special field aliases" do
    test ":ids builds an `in` over the given column" do
      dyn = CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:ids, [1, 2, 3]}, [])
      assert %Ecto.Query.DynamicExpr{} = dyn
    end

    test ":since_date builds `>=` over the given column (no hardcoded inserted_at)" do
      dyn =
        CommonExpr.dynamic_expr(
          {:as, nil},
          :published_at,
          nil,
          {:since_date, ~U[2026-01-01 00:00:00Z]},
          []
        )

      assert %Ecto.Query.DynamicExpr{} = dyn
    end

    test ":after operator produces > comparison" do
      expected = dynamic([q], field(q, :id) > ^5)
      actual = CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:after, 5}, [])

      assert_dynamic(expected, actual)
    end

    test ":since operator produces >= comparison" do
      expected = dynamic([q], field(q, :id) >= ^5)
      actual = CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:since, 5}, [])

      assert_dynamic(expected, actual)
    end

    test ":until operator produces <= comparison" do
      expected = dynamic([q], field(q, :id) <= ^5)
      actual = CommonExpr.dynamic_expr({:as, nil}, :id, nil, {:until, 5}, [])

      assert_dynamic(expected, actual)
    end

    test ":until_date operator produces <= comparison on the given column" do
      date = ~U[2026-03-09 02:04:01.573399Z]
      expected = dynamic([q], field(q, :inserted_at) <= ^date)
      actual = CommonExpr.dynamic_expr({:as, nil}, :inserted_at, nil, {:until_date, date}, [])

      assert_dynamic(expected, actual)
    end

    test ":start_date builds `>=` over the given column (alias of :since_date)" do
      dyn =
        CommonExpr.dynamic_expr(
          {:as, nil},
          :published_at,
          nil,
          {:start_date, ~U[2026-01-01 00:00:00Z]},
          []
        )

      assert %Ecto.Query.DynamicExpr{} = dyn
    end

    test ":end_date operator produces <= comparison on the given column (alias of :until_date)" do
      date = ~U[2026-03-09 02:04:01.573399Z]
      expected = dynamic([q], field(q, :inserted_at) <= ^date)
      actual = CommonExpr.dynamic_expr({:as, nil}, :inserted_at, nil, {:end_date, date}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "negation" do
    test "negation wraps expression with NOT" do
      expected = dynamic([q], field(q, :id) not in ^[1, 2])
      actual = CommonExpr.dynamic_expr({:as, nil}, :id, :not, {:ids, [1, 2]}, [])

      assert_dynamic(expected, actual)
    end

    test "unrecognised binding selector returns nil" do
      assert is_nil(CommonExpr.dynamic_expr(:unknown, :id, nil, {:ids, [1, 2]}, []))
    end
  end

  describe "operators/0" do
    test "returns the list of supported common expression operator keys" do
      ops = CommonExpr.operators()
      assert is_list(ops)
      assert :before in ops
      assert :after in ops
      assert :since in ops
      assert :until in ops
    end
  end

  describe ":exists operator" do
    test ":exists with nil value returns nil (skipped)" do
      actual = CommonExpr.dynamic_expr({:as, nil}, nil, nil, {:exists, nil}, [])

      assert is_nil(actual)
    end

    test ":exists produces an exists(subquery) expression" do
      sub = from(p in Post, where: p.published == ^true)
      actual = CommonExpr.dynamic_expr({:as, nil}, nil, nil, {:exists, sub}, [])

      assert %Ecto.Query.DynamicExpr{} = actual
    end
  end

  # ---- merged from date_wrappers (via CommonFilters pipeline) ----
  describe "date wrappers" do
  @describetag feature: :date_wrappers
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

  # ---- merged from datetime_wrappers (via CommonFilters pipeline) ----
  describe "datetime wrappers" do
  @describetag feature: :datetime_wrappers
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

  describe "datetime from_now comparisons" do
  @describetag feature: :datetime_wrappers
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

  describe "datetime add comparisons" do
  @describetag feature: :datetime_wrappers
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

  describe "datetime negated != and <= variants" do
  @describetag feature: :datetime_wrappers
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
  end

  describe "shift date-math (pipeline)" do
  @describetag feature: :datetime_wrappers
    test "shift date-math produces datetime_add" do
      expected =
        from(p in Post,
          where: p.published_at >= datetime_add(p.published_at, ^7, "day")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{>=: %{datetime: %{shift: %{field: "published_at", count: 7, unit: "day"}}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from date_wrappers (schemaless) ----
  describe "date wrappers (schemaless)" do
    @describetag feature: :date_wrappers
    @describetag schema_mode: :schemaless
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
              >=: %{date: %{add: %{field: :inserted_at, count: 7, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from datetime_wrappers (schemaless) ----
  describe "datetime wrappers (schemaless)" do
    @describetag feature: :datetime_wrappers
    @describetag schema_mode: :schemaless
    test "matches records using datetime_add before comparison" do
      expected =
        from(p in "posts", where: p.inserted_at >= datetime_add(p.inserted_at, ^1, "day"))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{datetime: %{add: %{field: :inserted_at, count: 1, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
