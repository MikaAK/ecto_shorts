defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres.ScalarExpr
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "root binding equality" do
    test "plain scalar value produces equality" do
      expected = dynamic([q], field(q, :id) == ^1)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, 1, [])

      assert_dynamic(expected, actual)
    end

    test "nil value produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :id)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, nil, [])

      assert_dynamic(expected, actual)
    end

    test "string field key stays dynamic" do
      expected = dynamic([q], field(q, :title) == ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, "hello", [])

      assert_dynamic(expected, actual)
    end

    test "{:==, value} produces equality" do
      expected = dynamic([q], field(q, :id) == ^1)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, 1}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, nil} produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :id)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, nil} produces IS NOT NULL" do
      expected = dynamic([q], not is_nil(field(q, :published_at)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :published_at, nil, {:!=, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, value} produces inequality" do
      expected = dynamic([q], field(q, :views) != ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:!=, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "DateTime struct value is preserved in comparisons" do
      dt = ~U[2026-01-01 00:00:00Z]
      expected = dynamic([q], field(q, :published_at) >= ^dt)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :published_at, nil, {:>=, dt}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "root binding comparison operators" do
    test "{:>, value} produces greater-than" do
      expected = dynamic([q], field(q, :views) > ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, wrapped_arithmetic} produces greater-than with arithmetic value" do
      expected = dynamic([q], field(q, :views) > field(q, :views) + ^10)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>, {:value, {:+, {{:field, :views}, {:value, 10}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>=, value} produces greater-than-or-equal" do
      expected = dynamic([q], field(q, :views) >= ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>=, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, value} produces less-than" do
      expected = dynamic([q], field(q, :views) < ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, value} produces less-than-or-equal" do
      expected = dynamic([q], field(q, :views) <= ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<=, 10}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "membership operators" do
    test "{:in, list} produces membership" do
      expected = dynamic([q], field(q, :id) in ^[1, 2, 3])
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:in, [1, 2, 3]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, list} produces membership" do
      expected = dynamic([q], field(q, :published) in ^[true, false])
      actual = ScalarExpr.dynamic_expr({:as, nil}, :published, nil, {:==, [true, false]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, list} produces negated membership with nil guard" do
      expected =
        dynamic([q], is_nil(field(q, :published)) or field(q, :published) not in ^[true, false])

      actual = ScalarExpr.dynamic_expr({:as, nil}, :published, nil, {:!=, [true, false]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "membership nil fallback" do
    test "{:in, non_list} routes to membership family but returns nil" do
      assert is_nil(ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:in, "not_a_list"}, []))
    end
  end

  describe "aggregate comparisons" do
    test "{:avg, comparison} produces aggregate comparison" do
      expected = dynamic([q], avg(field(q, :views)) > ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:avg, {:>, 10}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:avg, comparison} wraps aggregate with NOT" do
      expected = dynamic([q], not (avg(field(q, :views)) > ^10))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:avg, {:>, 10}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:==, nil}} produces is_nil aggregate check" do
      expected = dynamic([q], is_nil(count(field(q, :views))))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:count, {:==, nil}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:count, {:==, value}} produces aggregate inequality" do
      expected = dynamic([q], count(field(q, :views)) != ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:count, {:==, 5}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "quantified expressions" do
    test "{:==, {:all, subquery}} produces quantified equality" do
      subquery_expr =
        from(c in Comment,
          where: c.published == ^true,
          select: c.id
        )

      expected = dynamic([q], field(q, :id) == all(subquery_expr))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, {:all, subquery_expr}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:==, {:all, subquery}} wraps quantified equality with NOT" do
      subquery_expr =
        from(c in Comment,
          where: c.published == ^true,
          select: c.id
        )

      expected = dynamic([q], not (field(q, :id) == all(subquery_expr)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:==, {:all, subquery_expr}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "LIKE / ILIKE operators" do
    test "{:like, term} auto-wraps the term with percent signs" do
      expected = dynamic([q], like(field(q, :title), ^"%hello%"))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:like, "hello"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:like, pattern_with_wildcard} preserves caller-supplied wildcard pattern" do
      expected = dynamic([q], like(field(q, :title), ^"hello%"))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:like, "hello%"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:ilike, term} auto-wraps the term with percent signs" do
      expected = dynamic([q], ilike(field(q, :title), ^"%hello%"))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:ilike, "hello"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:like, list} produces LIKE ANY fragment with auto-wrapped patterns" do
      patterns = ["%hello%", "%world%"]

      expected =
        dynamic([q], fragment("? LIKE ANY(?)", field(q, :title), ^patterns))

      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:like, ["hello", "world"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:ilike, list} produces ILIKE ANY fragment with auto-wrapped patterns" do
      patterns = ["%hello%", "%world%"]

      expected =
        dynamic([q], fragment("? ILIKE ANY(?)", field(q, :title), ^patterns))

      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:ilike, ["hello", "world"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:like, integer} wraps integer with percent signs via non-binary fallback" do
      expected = dynamic([q], like(field(q, :title), ^"%123%"))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:like, 123}, [])

      assert_dynamic(expected, actual)
    end

    test "{:ilike, list_with_wildcards} preserves caller-supplied wildcard patterns" do
      patterns = ["hello%", "%world"]

      expected =
        dynamic([q], fragment("? ILIKE ANY(?)", field(q, :title), ^patterns))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:ilike, ["hello%", "%world"]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "string transform operators" do
    test "{:==, {:lower, value}} produces lower() equality" do
      expected = dynamic([q], fragment("lower(?)", field(q, :title)) == ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:==, {:lower, "hello"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, {:upper, value}} produces upper() equality" do
      expected = dynamic([q], fragment("upper(?)", field(q, :title)) == ^"HELLO")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:==, {:upper, "HELLO"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:lower, value}} produces lower() inequality" do
      expected = dynamic([q], fragment("lower(?)", field(q, :title)) != ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:!=, {:lower, "hello"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:upper, value}} produces upper() inequality" do
      expected = dynamic([q], fragment("upper(?)", field(q, :title)) != ^"HELLO")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:!=, {:upper, "HELLO"}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "negation" do
    test "negated {:in, list} produces NOT IN with nil guard" do
      expected =
        dynamic([q], is_nil(field(q, :published)) or field(q, :published) not in ^[true, false])

      actual = ScalarExpr.dynamic_expr({:as, nil}, :published, :not, {:in, [true, false]}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:>, value} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) > ^10))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:>, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:==, value} produces inequality" do
      expected = dynamic([q], field(q, :views) != ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:==, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:!=, value} produces equality (double negation)" do
      expected = dynamic([q], field(q, :views) == ^10)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:!=, 10}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:like, term} wraps LIKE with NOT" do
      expected = dynamic([q], not like(field(q, :title), ^"%hello%"))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:like, "hello"}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:like, list} wraps LIKE ANY with NOT" do
      patterns = ["%hello%", "%world%"]

      expected = dynamic([q], not fragment("? LIKE ANY(?)", field(q, :title), ^patterns))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:like, ["hello", "world"]}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:==, {:lower, value}} produces lower() inequality" do
      expected = dynamic([q], fragment("lower(?)", field(q, :title)) != ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:==, {:lower, "hello"}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "named binding alias" do
    test "plain scalar value on a named binding produces equality on that alias" do
      id = 1
      expected = from(p in Post, as: :post, where: p.id == ^id)

      actual =
        from(p in Post,
          as: :post,
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :id, nil, id, [])
        )

      assert_sql(expected, actual)
    end

    test "{:==, value} on a named binding produces equality on that alias" do
      id = 1
      expected = from(p in Post, as: :post, where: p.id == ^id)

      actual =
        from(p in Post,
          as: :post,
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :id, nil, {:==, id}, [])
        )

      assert_sql(expected, actual)
    end

    test "nil value on a named binding produces IS NULL on that alias" do
      expected = from(p in Post, as: :post, where: is_nil(p.id))

      actual =
        from(p in Post,
          as: :post,
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :id, nil, nil, [])
        )

      assert_sql(expected, actual)
    end

    test "{:>, value} on a named binding produces greater-than on that alias" do
      expected = from(p in Post, as: :post, where: p.views > ^10)

      actual =
        from(p in Post,
          as: :post,
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :views, nil, {:>, 10}, [])
        )

      assert_sql(expected, actual)
    end
  end

  describe "operators/0" do
    test "returns the list of supported scalar expression operator families" do
      ops = ScalarExpr.operators()
      assert is_list(ops)
      assert :membership in ops
      assert :comparison in ops
      assert :string_transform in ops
      assert :string in ops
    end
  end

  describe "positional binding" do
    test "plain scalar value on a positional binding produces equality on the correct join" do
      id = 1
      expected = dynamic([_, q], q.id == ^id)
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, id, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, value} on a positional binding produces equality on the correct join" do
      id = 1
      expected = dynamic([_, q], q.id == ^id)
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, {:==, id}, [])

      assert_dynamic(expected, actual)
    end

    test "nil value on a positional binding produces IS NULL on the correct join" do
      expected = dynamic([_, q], is_nil(q.id))
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, nil, [])

      assert_dynamic(expected, actual)
    end

    test "{:in, list} on a positional binding produces membership on the correct join" do
      expected = dynamic([_, q], q.id in ^[1, 2, 3])
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, {:in, [1, 2, 3]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe ":parent_as field comparisons" do
    test "{:==, {:parent_as, binding}} produces equality against parent binding" do
      expected = dynamic([q], field(q, :id) == field(parent_as(:post), :id))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, {:parent_as, {:post, :id}}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:==, {:parent_as, binding}} produces inequality against parent binding" do
      expected = dynamic([q], field(q, :id) != field(parent_as(:post), :id))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:==, {:parent_as, {:post, :id}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:parent_as, binding}} produces inequality against parent binding" do
      expected = dynamic([q], field(q, :id) != field(parent_as(:post), :id))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:!=, {:parent_as, {:post, :id}}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:!=, {:parent_as, binding}} produces equality against parent binding" do
      expected = dynamic([q], field(q, :id) == field(parent_as(:post), :id))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:!=, {:parent_as, {:post, :id}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:parent_as, binding}} produces >= against parent binding" do
      expected = dynamic([q], field(q, :views) >= field(parent_as(:post), :views))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>=, {:parent_as, {:post, :views}}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:>=, {:parent_as, binding}} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) >= field(parent_as(:post), :views)))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>=, {:parent_as, {:post, :views}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:parent_as, binding}} produces < against parent binding" do
      expected = dynamic([q], field(q, :views) < field(parent_as(:post), :views))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<, {:parent_as, {:post, :views}}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:<, {:parent_as, binding}} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) < field(parent_as(:post), :views)))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:<, {:parent_as, {:post, :views}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:parent_as, binding}} produces <= against parent binding" do
      expected = dynamic([q], field(q, :views) <= field(parent_as(:post), :views))

      actual =
        ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<=, {:parent_as, {:post, :views}}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:<=, {:parent_as, binding}} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) <= field(parent_as(:post), :views)))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<=, {:parent_as, {:post, :views}}},
          []
        )

      assert_dynamic(expected, actual)
    end
  end

  describe "string transform via comparison operators returns nil" do
    test "{:like, {:lower, value}} routes to :string_transform family and returns nil" do
      assert is_nil(
               ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:like, {:lower, "hello"}}, [])
             )
    end

    test "{:ilike, {:upper, value}} routes to :string_transform family and returns nil" do
      assert is_nil(
               ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:ilike, {:upper, "HELLO"}}, [])
             )
    end
  end

  describe "date wrapper expressions" do
    test "{:==, {:date, {:ago, ...}}} produces date equality using ago" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) == fragment("date(?)", ago(^1, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:==, {:date, {:ago, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:!=, {:date, {:from_now, ...}}} produces date inequality using from_now" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) != fragment("date(?)", from_now(^1, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:!=, {:date, {:from_now, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "negated {:>, {:date, {:from_now, ...}}} wraps date comparison with NOT" do
      expected =
        from(p in Post,
          where:
            not (fragment("date(?)", p.inserted_at) > fragment("date(?)", from_now(^1, "day")))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:not, {:>, {:date, {:from_now, [count: 1, interval: "day"]}}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:>=, {:date, {:add, ...}}} produces date >= using datetime_add" do
      expected =
        dynamic(
          [q],
          fragment("date(?)", field(q, :inserted_at)) >=
            fragment("date(?)", datetime_add(field(q, :inserted_at), ^7, "day"))
        )

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>=, {:date, {:add, [field: :inserted_at, count: 7, interval: "day"]}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "date add params in different keyword order produce the same expression" do
      expected =
        dynamic(
          [q],
          fragment("date(?)", field(q, :inserted_at)) >=
            fragment("date(?)", datetime_add(field(q, :inserted_at), ^7, "day"))
        )

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>=, {:date, {:add, [interval: "day", field: :inserted_at, count: 7]}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:date, {:ago, ..., :month}}} produces date less-than using ago with month interval" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) < fragment("date(?)", ago(^1, "month"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<, {:date, {:ago, [count: 1, interval: "month"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "date ago params in different keyword order produce the same expression" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.inserted_at) < fragment("date(?)", ago(^1, "month"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<, {:date, {:ago, [interval: "month", count: 1]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end
  end

  describe "datetime wrapper expressions" do
    test "{:>=, {:datetime, {:add, ...}}} preserves datetime_add when params arrive in different keyword order" do
      expected =
        dynamic(
          [q],
          field(q, :inserted_at) >= datetime_add(field(q, :inserted_at), ^1, "day")
        )

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>=, {:datetime, {:add, [interval: "day", field: :inserted_at, count: 1]}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>, {:datetime, {:ago, ...}}} produces datetime greater-than using ago" do
      expected =
        from(p in Post,
          where: p.inserted_at > ago(^1, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>, {:datetime, {:ago, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:>, {:datetime, {:from_now, ...}}} produces datetime greater-than using from_now" do
      expected =
        from(p in Post,
          where: p.inserted_at > from_now(^1, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>, {:datetime, {:from_now, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "negated {:>=, {:datetime, {:add, ...}}} wraps datetime_add with NOT" do
      expected =
        dynamic(
          [q],
          not (field(q, :inserted_at) >= datetime_add(field(q, :inserted_at), ^1, "day"))
        )

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:not, {:>=, {:datetime, {:add, [field: :inserted_at, count: 1, interval: "day"]}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:datetime, {:ago, ...}}} produces datetime less-than using ago" do
      expected =
        from(p in Post,
          where: p.inserted_at < ago(^7, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<, {:datetime, {:ago, [count: 7, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:<=, {:datetime, {:from_now, ...}}} produces datetime less-than-or-equal using from_now" do
      expected =
        from(p in Post,
          where: p.inserted_at <= from_now(^30, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<=, {:datetime, {:from_now, [count: 30, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "negated {:<, {:datetime, {:ago, ...}}} wraps datetime less-than with NOT" do
      expected =
        from(p in Post,
          where: not (p.inserted_at < ago(^7, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:not, {:<, {:datetime, {:ago, [count: 7, interval: "day"]}}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:==, {:datetime, {:ago, ...}}} produces datetime equality via generic path" do
      expected =
        from(p in Post,
          where: p.inserted_at == ago(^1, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:==, {:datetime, {:ago, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "negated {:==, {:datetime, {:ago, ...}}} produces datetime inequality via generic path" do
      expected =
        from(p in Post,
          where: p.inserted_at != ago(^1, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          :not,
          {:==, {:datetime, {:ago, [count: 1, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:<, {:datetime, {:from_now, ...}}} produces datetime less-than via generic path" do
      expected =
        from(p in Post,
          where: p.inserted_at < from_now(^7, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<, {:datetime, {:from_now, [count: 7, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "negated {:<, {:datetime, {:from_now, ...}}} wraps with NOT via generic path" do
      expected =
        from(p in Post,
          where: not (p.inserted_at < from_now(^7, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          :not,
          {:<, {:datetime, {:from_now, [count: 7, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end
  end

end
