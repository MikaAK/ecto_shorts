defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias Ecto.Adapters.SQL
  alias EctoShorts.CommonFilters
  alias EctoShorts.Config
  alias EctoShorts.DynamicBuilders.Postgres.ScalarExpr
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog



  describe "root binding equality" do
    test "plain scalar value produces equality" do
      expected = dynamic([q], field(q, :id) == ^1)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, 1}, [])

      assert_dynamic(expected, actual)
    end

    test "nil value produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :id)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:==, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "string field key stays dynamic" do
      expected = dynamic([q], field(q, :title) == ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:==, "hello"}, [])

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

    test "datetime struct value is preserved in comparisons" do
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
        dynamic([q], field(q, :published) not in ^[true, false])

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
        dynamic([q], field(q, :published) not in ^[true, false])

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
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :id, nil, {:==, id}, [])
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
          where: ^ScalarExpr.dynamic_expr({:as, :post}, :id, nil, {:==, nil}, [])
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
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, {:==, id}, [])

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
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, {:==, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:in, list} on a positional binding produces membership on the correct join" do
      expected = dynamic([_, q], q.id in ^[1, 2, 3])
      actual = ScalarExpr.dynamic_expr({:at, 2}, :id, nil, {:in, [1, 2, 3]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "field / sibling / arithmetic operands" do
    test "{:>, {:field, col}} compares to another column on the current binding" do
      expected = dynamic([q], field(q, :views) > field(q, :id))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>, {:field, :id}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:field, {binding, col}}} compares to a column on a sibling binding" do
      expected = dynamic([q], field(q, :views) > field(as(:author), :age))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>, {:field, {:author, :age}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:+, [field, value]}} compares against computed-field arithmetic" do
      expected = dynamic([q], field(q, :views) > field(q, :id) + ^5)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>, {:+, [{:field, :id}, {:value, 5}]}},
          []
        )

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

  describe "string transform negated variants" do
    test "{:not, {:==, {:upper, value}}} produces upper() inequality" do
      expected = dynamic([q], fragment("upper(?)", field(q, :title)) != ^"HELLO")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:==, {:upper, "HELLO"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:!=, {:upper, value}}} produces upper() equality (double negation)" do
      expected = dynamic([q], fragment("upper(?)", field(q, :title)) == ^"HELLO")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:!=, {:upper, "HELLO"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:!=, {:lower, value}}} produces lower() equality (double negation)" do
      expected = dynamic([q], fragment("lower(?)", field(q, :title)) == ^"hello")
      actual = ScalarExpr.dynamic_expr({:as, nil}, :title, :not, {:!=, {:lower, "hello"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:lower, value}} routes to :string_transform family and returns nil" do
      assert is_nil(ScalarExpr.dynamic_expr({:as, nil}, :title, nil, {:>, {:lower, "hello"}}, []))
    end
  end

  describe "value wrapper comparisons" do
    test "{:==, {:value, v}} produces equality" do
      expected = dynamic([q], field(q, :views) == ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:==, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:!=, {:value, v}}} produces equality (double negation)" do
      expected = dynamic([q], field(q, :views) == ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:!=, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:value, v}} produces greater-than-or-equal" do
      expected = dynamic([q], field(q, :views) >= ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>=, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, {:value, v}} produces less-than" do
      expected = dynamic([q], field(q, :views) < ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:<, {:value, v}}} wraps less-than with NOT" do
      expected = dynamic([q], not (field(q, :views) < ^5))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:<, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:value, v}} produces less-than-or-equal" do
      expected = dynamic([q], field(q, :views) <= ^5)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:<=, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:<=, {:value, v}}} wraps less-than-or-equal with NOT" do
      expected = dynamic([q], not (field(q, :views) <= ^5))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:<=, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "quantified comparisons - inequality and ordering" do
    test "{:!=, {:all, subquery}} produces not-equal-to-all" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) != all(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:!=, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:!=, {:all, subquery}}} wraps not-equal-to-all with NOT" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], not (field(q, :id) != all(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:!=, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:any, subquery}} produces not-equal-to-any" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) != any(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:!=, {:any, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:all, subquery}} produces greater-than-all" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) > all(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:>, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:>, {:any, subquery}}} wraps greater-than-any with NOT" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], not (field(q, :id) > any(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:>, {:any, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:all, subquery}} produces greater-than-or-equal-to-all" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) >= all(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:>=, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:>=, {:any, subquery}}} wraps >= any with NOT" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], not (field(q, :id) >= any(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:>=, {:any, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, {:all, subquery}} produces less-than-all" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) < all(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:<, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:<, {:any, subquery}}} wraps less-than-any with NOT" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], not (field(q, :id) < any(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:<, {:any, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:all, subquery}} produces less-than-or-equal-to-all" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], field(q, :id) <= all(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:<=, {:all, sq}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:not, {:<=, {:any, subquery}}} wraps <= any with NOT" do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      expected = dynamic([q], not (field(q, :id) <= any(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:<=, {:any, sq}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "arithmetic with subtraction, multiplication, division" do
    test "{:>, wrapped_arithmetic with -} produces greater-than with subtraction" do
      expected = dynamic([q], field(q, :views) > field(q, :views) - ^3)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>, {:value, {:-, {{:field, :views}, {:value, 3}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:not, {:>, wrapped_arithmetic with -}} wraps subtraction comparison with NOT" do
      expected = dynamic([q], not (field(q, :views) > field(q, :views) - ^3))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>, {:value, {:-, {{:field, :views}, {:value, 3}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>, wrapped_arithmetic with *} produces greater-than with multiplication" do
      expected = dynamic([q], field(q, :views) > field(q, :views) * ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>, wrapped_arithmetic with /} produces greater-than with division" do
      expected = dynamic([q], field(q, :views) > field(q, :views) / ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
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

    test "{:>=, {:datetime, {:shift, ...}}} emits datetime_add (same SQL as :add)" do
      expected =
        dynamic(
          [q],
          field(q, :inserted_at) >= datetime_add(field(q, :inserted_at), ^7, "day")
        )

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>=, {:datetime, {:shift, [count: 7, interval: "day", field: :inserted_at]}}},
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

    test "{:==, {:datetime, {:ago, ...}}} produces equality with an ago datetime value" do
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

    test "negated {:==, {:datetime, {:ago, ...}}} produces inequality with an ago datetime value" do
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

    test "{:<, {:datetime, {:from_now, ...}}} produces less-than comparison with a from_now datetime value" do
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

    test "negated {:<, {:datetime, {:from_now, ...}}} wraps the less-than comparison with NOT" do
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

    test "{:>=, {:datetime, {:ago, ...}}} falls through to generic path and produces >= with ago" do
      expected =
        from(p in Post,
          where: p.inserted_at >= ago(^7, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:>=, {:datetime, {:ago, [count: 7, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:not, {:>=, {:datetime, {:ago, ...}}}} falls through to generic path and wraps with NOT" do
      expected =
        from(p in Post,
          where: not (p.inserted_at >= ago(^7, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:not, {:>=, {:datetime, {:ago, [count: 7, interval: "day"]}}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:<=, {:datetime, {:ago, ...}}} falls through to generic path and produces <= with ago" do
      expected =
        from(p in Post,
          where: p.inserted_at <= ago(^30, "day")
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:<=, {:datetime, {:ago, [count: 30, interval: "day"]}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end

    test "{:not, {:<=, {:datetime, {:from_now, ...}}}} falls through to generic path and wraps with NOT" do
      expected =
        from(p in Post,
          where: not (p.inserted_at <= from_now(^14, "day"))
        )

      actual_dynamic =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :inserted_at,
          nil,
          {:not, {:<=, {:datetime, {:from_now, [count: 14, interval: "day"]}}}},
          []
        )

      actual = from(p in Post, where: ^actual_dynamic)

      assert_sql(expected, actual)
    end
  end

  describe "dynamic_expr/5 catch-all fallback" do
    test "unsupported binding returns nil" do
      assert is_nil(ScalarExpr.dynamic_expr(:unsupported_binding, :id, nil, {:==, 1}, []))
    end
  end

  describe "negated simple scalar comparisons not yet covered" do
    test "negated {:>=, value} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) >= ^10))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:>=, 10}, [])
      assert_dynamic(expected, actual)
    end

    test "negated {:<=, value} wraps with NOT" do
      expected = dynamic([q], not (field(q, :views) <= ^10))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:<=, 10}, [])
      assert_dynamic(expected, actual)
    end
  end

  describe "comparison_impl unknown operator fallback" do
    test "unknown operator returns nil" do
      assert is_nil(ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:custom_op, 10}, []))
    end
  end

  describe "generic scalar fallback via apply_scalar_comparison" do
    test "unknown tuple value with comparison op routes to plain apply_scalar_comparison" do
      v = {:custom_thing, 5}
      expected = dynamic([q], field(q, :views) >= ^v)
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>=, {:custom_thing, 5}}, [])
      assert_dynamic(expected, actual)
    end

    test "negated unknown tuple value with comparison op routes to negated apply_scalar_comparison" do
      v = {:custom_thing, 5}
      expected = dynamic([], not (^dynamic([q], field(q, :views)) >= ^v))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :views, :not, {:>=, {:custom_thing, 5}}, [])
      assert_dynamic(expected, actual)
    end
  end

  describe "quantified comparisons - remaining variants" do
    setup do
      sq = from(c in Comment, where: c.published == ^true, select: c.id)
      %{sq: sq}
    end

    test "negated {:!=, {:any, subquery}} wraps NOT != ANY", %{sq: sq} do
      expected = dynamic([q], not (field(q, :id) != any(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:!=, {:any, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "negated {:>, {:all, subquery}} wraps NOT > ALL", %{sq: sq} do
      expected = dynamic([q], not (field(q, :id) > all(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:>, {:all, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "negated {:>=, {:all, subquery}} wraps NOT >= ALL", %{sq: sq} do
      expected = dynamic([q], not (field(q, :id) >= all(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:>=, {:all, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "{:>=, {:any, subquery}} produces >= ANY", %{sq: sq} do
      expected = dynamic([q], field(q, :id) >= any(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:>=, {:any, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "negated {:<, {:all, subquery}} wraps NOT < ALL", %{sq: sq} do
      expected = dynamic([q], not (field(q, :id) < all(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:<, {:all, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "{:<, {:any, subquery}} produces < ANY", %{sq: sq} do
      expected = dynamic([q], field(q, :id) < any(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:<, {:any, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "negated {:<=, {:all, subquery}} wraps NOT <= ALL", %{sq: sq} do
      expected = dynamic([q], not (field(q, :id) <= all(sq)))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, :not, {:<=, {:all, sq}}, [])
      assert_dynamic(expected, actual)
    end

    test "{:<=, {:any, subquery}} produces <= ANY", %{sq: sq} do
      expected = dynamic([q], field(q, :id) <= any(sq))
      actual = ScalarExpr.dynamic_expr({:as, nil}, :id, nil, {:<=, {:any, sq}}, [])
      assert_dynamic(expected, actual)
    end
  end

  describe "arithmetic negated and remaining operators" do
    test "negated {:>, {:value, {:+, field_value}}} wraps NOT > field + value" do
      expected = dynamic([q], not (field(q, :views) > field(q, :views) + ^5))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>, {:value, {:+, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:value, {:-, field_value}}} produces != field - value" do
      expected = dynamic([q], field(q, :views) != field(q, :views) - ^5)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:!=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:!=, {:value, {:-, field_value}}} wraps NOT != field - value" do
      expected = dynamic([q], not (field(q, :views) != field(q, :views) - ^5))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:!=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:value, {:-, field_value}}} produces >= field - value" do
      expected = dynamic([q], field(q, :views) >= field(q, :views) - ^5)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:>=, {:value, {:-, field_value}}} wraps NOT >= field - value" do
      expected = dynamic([q], not (field(q, :views) >= field(q, :views) - ^5))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:value, {:-, field_value}}} produces < field - value" do
      expected = dynamic([q], field(q, :views) < field(q, :views) - ^5)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<, {:value, {:-, field_value}}} wraps NOT < field - value" do
      expected = dynamic([q], not (field(q, :views) < field(q, :views) - ^5))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:value, {:-, field_value}}} produces <= field - value" do
      expected = dynamic([q], field(q, :views) <= field(q, :views) - ^5)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<=, {:value, {:-, field_value}}} wraps NOT <= field - value" do
      expected = dynamic([q], not (field(q, :views) <= field(q, :views) - ^5))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<=, {:value, {:-, {{:field, :views}, {:value, 5}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:value, {:*, field_value}}} produces != field * value" do
      expected = dynamic([q], field(q, :views) != field(q, :views) * ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:!=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:!=, {:value, {:*, field_value}}} wraps NOT != field * value" do
      expected = dynamic([q], not (field(q, :views) != field(q, :views) * ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:!=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:>, {:value, {:*, field_value}}} wraps NOT > field * value" do
      expected = dynamic([q], not (field(q, :views) > field(q, :views) * ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:value, {:*, field_value}}} produces >= field * value" do
      expected = dynamic([q], field(q, :views) >= field(q, :views) * ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:>=, {:value, {:*, field_value}}} wraps NOT >= field * value" do
      expected = dynamic([q], not (field(q, :views) >= field(q, :views) * ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:value, {:*, field_value}}} produces < field * value" do
      expected = dynamic([q], field(q, :views) < field(q, :views) * ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<, {:value, {:*, field_value}}} wraps NOT < field * value" do
      expected = dynamic([q], not (field(q, :views) < field(q, :views) * ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:value, {:*, field_value}}} produces <= field * value" do
      expected = dynamic([q], field(q, :views) <= field(q, :views) * ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<=, {:value, {:*, field_value}}} wraps NOT <= field * value" do
      expected = dynamic([q], not (field(q, :views) <= field(q, :views) * ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<=, {:value, {:*, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:==, {:value, {:/, field_value}}} wraps NOT == field / value" do
      expected = dynamic([q], not (field(q, :views) == field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:==, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:value, {:/, field_value}}} produces != field / value" do
      expected = dynamic([q], field(q, :views) != field(q, :views) / ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:!=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:!=, {:value, {:/, field_value}}} wraps NOT != field / value" do
      expected = dynamic([q], not (field(q, :views) != field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:!=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:>, {:value, {:/, field_value}}} wraps NOT > field / value" do
      expected = dynamic([q], not (field(q, :views) > field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:>=, {:value, {:/, field_value}}} produces >= field / value" do
      expected = dynamic([q], field(q, :views) >= field(q, :views) / ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:>=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:>=, {:value, {:/, field_value}}} wraps NOT >= field / value" do
      expected = dynamic([q], not (field(q, :views) >= field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:>=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<, {:value, {:/, field_value}}} produces < field / value" do
      expected = dynamic([q], field(q, :views) < field(q, :views) / ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<, {:value, {:/, field_value}}} wraps NOT < field / value" do
      expected = dynamic([q], not (field(q, :views) < field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:value, {:/, field_value}}} produces <= field / value" do
      expected = dynamic([q], field(q, :views) <= field(q, :views) / ^2)

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          nil,
          {:<=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "negated {:<=, {:value, {:/, field_value}}} wraps NOT <= field / value" do
      expected = dynamic([q], not (field(q, :views) <= field(q, :views) / ^2))

      actual =
        ScalarExpr.dynamic_expr(
          {:as, nil},
          :views,
          :not,
          {:<=, {:value, {:/, {{:field, :views}, {:value, 2}}}}},
          []
        )

      assert_dynamic(expected, actual)
    end
  end

  # ---- merged from comparison_operators (via CommonFilters pipeline) ----
  describe "ordering operator vs nil (D-RAISE)" do
  @describetag feature: :comparison_operators
    test "an ordering operator given nil raises" do
      for op <- [:gt, :gte, :lt, :lte] do
        assert_raise EctoShorts.FilterError, ~r/cannot be compared to nil/, fn ->
          CommonFilters.convert_params_to_filter(Post, %{views: %{op => nil}}, [])
        end
      end
    end
  end

  describe "comparison operators" do
  @describetag feature: :comparison_operators
    test "matches records where the field equals the value using ==" do
      expected = from(p in Post, where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter(Post, %{id: %{==: 1}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is nil using == nil" do
      expected = from(p in Post, where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{==: nil}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is not nil using != nil" do
      expected = from(p in Post, where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{!=: nil}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is greater than the value" do
      expected = from(p in Post, where: p.views > ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{>: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is greater than or equal to the value" do
      expected = from(p in Post, where: p.views >= ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{>=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is less than the value" do
      expected = from(p in Post, where: p.views < ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{<: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is less than or equal to the value" do
      expected = from(p in Post, where: p.views <= ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{<=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field does not equal the value using !=" do
      expected = from(p in Post, where: p.views != ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is in the given list" do
      expected = from(p in Post, where: p.published in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{in: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "treats a list value with == as an IN check" do
      expected = from(p in Post, where: p.published in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{==: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "treats a list value with != as a NOT IN check" do
      expected = from(p in Post, where: p.published not in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{!=: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "preserves struct values like DateTime in the comparison" do
      dt = ~U[2026-01-01 00:00:00Z]
      expected = from(p in Post, where: p.published_at >= ^dt)
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{>=: dt}}, [])

      assert_sql(expected, q2)
    end

    test "matches records using quantified default equality shorthand" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{all: %{from: Comment, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified any default equality shorthand" do
      expected =
        from(p in Post,
          where:
            p.id ==
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{any: %{from: Comment, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified select override" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.post_id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{all: %{from: Comment, select: %{field: "post_id"}, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified any select override" do
      expected =
        from(p in Post,
          where:
            p.id ==
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.post_id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{any: %{from: Comment, select: %{field: "post_id"}, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "falls back to the default quantified select field when a string override is invalid" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                id: %{
                  all: %{
                    from: Comment,
                    select: %{field: "does_not_exist"},
                    where: %{published: true}
                  }
                }
              },
              []
            )

          assert_sql(expected, actual)
        end)

      assert log =~ "does_not_exist"
    end

    test "matches records using quantified greater-than all comparison" do
      expected =
        from(p in Post,
          where:
            p.id >
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{>: %{all: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified greater-than any comparison" do
      expected =
        from(p in Post,
          where:
            p.id >
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{>: %{any: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using the explicit value wrapper for arithmetic expressions" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "raises for an unsupported nil operator" do
      assert_raise EctoShorts.FilterError, ~r/cannot be compared to nil/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{published_at: %{>: nil}}, [])
      end
    end
  end

  describe "arithmetic negation" do
  @describetag feature: :comparison_operators
    test "excludes records using negated arithmetic comparison" do
      expected = from(p in Post, where: not (p.views == p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "value wrapper negation" do
  @describetag feature: :comparison_operators
    test "excludes records using negated value-wrapped comparison" do
      expected = from(p in Post, where: p.views != ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: 10}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated value-wrapped greater-than" do
      expected = from(p in Post, where: not (p.views > ^5))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>: %{value: 5}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "generic scalar fallback" do
  @describetag feature: :comparison_operators
    test "matches records using the generic scalar != fallback" do
      expected = from(p in Post, where: p.views != ^5)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: %{value: 5}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using the negated generic scalar >= fallback" do
      expected = from(p in Post, where: not (p.views >= ^5))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{>=: %{value: 5}}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "generic datetime comparisons" do
  @describetag feature: :comparison_operators
    test "matches records using a datetime ago comparison with date casting" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.published_at) == fragment("date(?)", ago(^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{==: %{date: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using a negated datetime ago comparison with date casting" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.published_at) != fragment("date(?)", ago(^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{==: %{date: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic + variants" do
  @describetag feature: :comparison_operators
    test "views == views + 10 (plain)" do
      expected = from(p in Post, where: p.views == p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views != views + 10 (plain)" do
      expected = from(p in Post, where: p.views != p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{!=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views > views + 10 (plain)" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views >= views + 10 (plain)" do
      expected = from(p in Post, where: p.views >= p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views < views + 10 (plain)" do
      expected = from(p in Post, where: p.views < p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{<: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views <= views + 10 (plain)" do
      expected = from(p in Post, where: p.views <= p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{<=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views != views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views != p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{!=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views >= views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views >= p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views < views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views < p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{<: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views <= views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views <= p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{<=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic - variants" do
  @describetag feature: :comparison_operators
    test "views == views - 5 (plain)" do
      expected = from(p in Post, where: p.views == p.views - ^5)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{-: [%{field: "views"}, %{value: 5}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views == views - 5) (negated)" do
      expected = from(p in Post, where: not (p.views == p.views - ^5))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{-: [%{field: "views"}, %{value: 5}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic * variants" do
  @describetag feature: :comparison_operators
    test "views == views * 2 (plain)" do
      expected = from(p in Post, where: p.views == p.views * ^2)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{*: [%{field: "views"}, %{value: 2}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views == views * 2) (negated)" do
      expected = from(p in Post, where: not (p.views == p.views * ^2))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{*: [%{field: "views"}, %{value: 2}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic / variants" do
  @describetag feature: :comparison_operators
    test "views == views / 2 (plain)" do
      expected = from(p in Post, where: p.views == p.views / ^2)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{/: [%{field: "views"}, %{value: 2}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views >= views / 2) (negated)" do
      expected = from(p in Post, where: not (p.views >= p.views / ^2))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>=: %{value: %{/: [%{field: "views"}, %{value: 2}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "operator pipeline coverage" do
  @describetag feature: :comparison_operators
    test "overlaps on an array field produces &&" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["a", "b"]))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{tags: %{overlaps: ["a", "b"]}},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "column (sibling) compare against another field on the same binding" do
      expected = from(p in Post, where: p.views == p.id)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{==: %{field: "id"}}}, [])

      assert_query(expected, actual)
    end

    test "binary arithmetic compare (field + value)" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from negation (via CommonFilters pipeline) ----
  describe "negation (merged 1)" do
  @describetag feature: :negation
    test "excludes records where the field is in the given list" do
      expected = from(p in Post, where: p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records when == with a list is wrapped in not" do
      expected = from(p in Post, where: p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{==: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "includes records when != with a list is wrapped in not" do
      expected = from(p in Post, where: p.published in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{!=: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records where the field is greater than the value" do
      expected = from(p in Post, where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{>: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field equals the value" do
      expected = from(p in Post, where: p.views != ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{==: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated quantified equality" do
      expected =
        from(p in Post,
          where:
            not (p.id ==
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{all: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated quantified any equality" do
      expected =
        from(p in Post,
          where:
            not (p.id ==
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{any: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "includes records where the field equals the value using double negation" do
      expected = from(p in Post, where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{!=: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "includes records where the field equals the value using negated ne alias" do
      expected = from(p in Post, where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{ne: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated gt alias" do
      expected = from(p in Post, where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{gt: 10}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "negated string transforms" do
  @describetag feature: :negation
    test "includes records where the lowercased field matches the value using not !=" do
      expected = from(p in Post, where: fragment("lower(?)", p.title) == ^"hello")

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{!=: %{lower: "hello"}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "negated nil checks" do
  @describetag feature: :negation
    test "excludes nil using not ==" do
      expected = from(p in Post, where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{not: %{==: nil}}}, [])

      assert_sql(expected, q2)
    end

    test "includes nil using not !=" do
      expected = from(p in Post, where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{not: %{!=: nil}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "negated quantified comparisons" do
  @describetag feature: :negation
    test "excludes records using negated != all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id !=
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{!=: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated > any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id >
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{>: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "negated aggregate nil checks" do
  @describetag feature: :negation
    test "excludes nil aggregate using not ==" do
      expected = from(p in Post, group_by: p.id, having: not is_nil(avg(p.views)))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{==: nil}}}}, [])

      assert_sql(expected, actual)
    end

    test "includes nil aggregate using not !=" do
      expected = from(p in Post, group_by: p.id, having: is_nil(avg(p.views)))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{!=: nil}}}}, [])

      assert_sql(expected, actual)
    end

    test "aggregate == nil produces is_nil check" do
      expected = from(p in Post, group_by: p.id, having: is_nil(sum(p.views)))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{==: nil}}}, [])

      assert_sql(expected, actual)
    end

    test "aggregate != nil produces not is_nil check" do
      expected = from(p in Post, group_by: p.id, having: not is_nil(sum(p.views)))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{!=: nil}}}, [])

      assert_sql(expected, actual)
    end

    test "negated aggregate <= produces not <= check" do
      expected = from(p in Post, group_by: p.id, having: not (avg(p.views) <= ^10))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{<=: 10}}}}, [])

      assert_sql(expected, actual)
    end

    test "negated aggregate != produces == check" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) == ^50)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{!=: 50}}}}, [])

      assert_sql(expected, actual)
    end
  end

  describe "not-in over a list (D-NULL)" do
  @describetag feature: :negation
    test "not-in over a list (plain NOT IN, no null guard added)" do
      expected = from(p in Post, where: p.views not in ^[1, 2, 3])
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{nin: [1, 2, 3]}}, [])

      assert_query(expected, actual)
    end
  end

  # ---- merged from string_matching (via CommonFilters pipeline) ----
  describe "string matching" do
  @describetag feature: :string_matching
    test "matches records where the field contains the text using like" do
      expected = from(p in Post, where: like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{like: "hello"}}, [])

      assert_sql(expected, q2)
    end

    # Bare string values are wrapped as `%value%`. Values that already contain `%`
    # or `_` are forwarded unchanged. `assert_sql/2` compares SQL strings only, not
    # bound parameters, so `to_sql/3` tuple equality is used to verify the parameter.
    test "preserves caller-supplied wildcard patterns using like" do
      expected = from(p in Post, where: like(p.title, ^"hello%"))
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{like: "hello%"}}, [])

      assert SQL.to_sql(:all, Config.repo(), expected) ===
               SQL.to_sql(:all, Config.repo(), q2)
    end

    test "matches records where the field contains the text case-insensitively using ilike" do
      expected = from(p in Post, where: ilike(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "hello"}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field matches any pattern in the like list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in Post,
          where: fragment("? LIKE ANY(?)", p.title, ^patterns)
        )

      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{like: ["hello", "world"]}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field matches any pattern in the ilike list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in Post,
          where: fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: ["hello", "world"]}}, [])

      assert_sql(expected, q2)
    end

    # Each element in the list is checked independently: bare strings are wrapped,
    # patterns containing `%` or `_` are forwarded unchanged. Uses `to_sql/3` tuple
    # equality to verify bound parameter values.
    test "preserves caller-supplied wildcard patterns in the ilike list" do
      patterns = ["hello%", "%world"]

      expected =
        from(p in Post,
          where: fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: ["hello%", "%world"]}}, [])

      assert SQL.to_sql(:all, Config.repo(), expected) ===
               SQL.to_sql(:all, Config.repo(), q2)
    end

    test "excludes records where the field contains the text using negated like" do
      expected = from(p in Post, where: not like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{not: %{like: "hello"}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field contains the text using negated ilike" do
      expected = from(p in Post, where: not ilike(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{not: %{ilike: "hello"}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field matches any pattern in the negated like list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in Post,
          where: not fragment("? LIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{like: ["hello", "world"]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records where the field matches any pattern in the negated ilike list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in Post,
          where: not fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{ilike: ["hello", "world"]}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  # ---- merged from string_transformations (via CommonFilters pipeline) ----
  describe "string transformations" do
  @describetag feature: :string_transformations
    test "matches records by comparing the lowercased field to the value" do
      expected = from(p in Post, where: fragment("lower(?)", p.title) == ^"hello")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{==: %{lower: "hello"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the uppercased field to the value" do
      expected = from(p in Post, where: fragment("upper(?)", p.title) == ^"HELLO")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{==: %{upper: "HELLO"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the trimmed field to the value" do
      expected = from(p in Post, where: fragment("trim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{trim: "al"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the left-trimmed field to the value" do
      expected = from(p in Post, where: fragment("ltrim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{ltrim: "al"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the right-trimmed field to the value" do
      expected = from(p in Post, where: fragment("rtrim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{rtrim: "al"}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the lowercased field equals the value" do
      expected = from(p in Post, where: fragment("lower(?)", p.title) != ^"hello")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{!=: %{lower: "hello"}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the uppercased field equals the value" do
      expected = from(p in Post, where: fragment("upper(?)", p.title) != ^"HELLO")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{!=: %{upper: "HELLO"}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the lowercased field matches using negated ==" do
      expected = from(p in Post, where: fragment("lower(?)", p.title) != ^"hello")

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{==: %{lower: "hello"}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records where the uppercased field matches using negated ==" do
      expected = from(p in Post, where: fragment("upper(?)", p.title) != ^"HELLO")

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{==: %{upper: "HELLO"}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "trim transform (pipeline)" do
  @describetag feature: :string_transformations
    test "trim transform on a scalar field" do
      expected = from(p in Post, where: fragment("trim(?)", p.title) == ^"hello")
      actual = CommonFilters.convert_params_to_filter(Post, %{title: %{==: %{trim: "hello"}}}, [])

      assert_query(expected, actual)
    end
  end

  # ---- merged from aggregate_operators (via CommonFilters pipeline) ----
  describe "aggregate operators" do
  @describetag feature: :aggregate_operators
    test "rule statement 1: avg views greater than" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{>: 10}}}, [])

      assert_sql(expected, actual)
    end

    # `not: %{avg: %{>: value}}` produces `not (avg(field) > value)`.
    test "rule statement 2: avg views greater than negated" do
      expected = from(p in Post, group_by: p.id, having: not (avg(p.views) > ^10))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{>: 10}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 3: count views greater than zero" do
      expected = from(p in Post, group_by: p.id, having: count(p.views) > ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{count: %{>: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 4: max views greater than or equal" do
      expected = from(p in Post, group_by: p.id, having: max(p.views) >= ^100)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{max: %{>=: 100}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 5: min views less than" do
      expected = from(p in Post, group_by: p.id, having: min(p.views) < ^5)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{min: %{<: 5}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 6: sum views equals" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) == ^1000)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{==: 1000}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 7: avg views not equals" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) != ^50)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{!=: 50}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 8: count views equals zero" do
      expected = from(p in Post, group_by: p.id, having: count(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{count: %{==: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 9: count views greater than zero negated" do
      expected = from(p in Post, group_by: p.id, having: not (count(p.views) > ^0))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{count: %{>: 0}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 10: max views greater than or equal negated" do
      expected = from(p in Post, group_by: p.id, having: not (max(p.views) >= ^100))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{max: %{>=: 100}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 11: avg views less than or equal" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) <= ^10)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{<=: 10}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 12: sum views greater than" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) > ^500)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{>: 500}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 13: min views equals zero" do
      expected = from(p in Post, group_by: p.id, having: min(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{min: %{==: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 14: sum views not equals zero" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) != ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{!=: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 15: min views less than negated" do
      expected = from(p in Post, group_by: p.id, having: not (min(p.views) < ^5))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{min: %{<: 5}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 16: sum views greater than negated" do
      expected = from(p in Post, group_by: p.id, having: not (sum(p.views) > ^500))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{sum: %{>: 500}}}}, [])

      assert_sql(expected, actual)
    end
  end

  describe "aggregate placement (where -> having, auto group_by)" do
  @describetag feature: :aggregate_operators
    test "an aggregate written under :where lands in HAVING with an auto GROUP BY" do
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{gt: 5}}}, [])
      assert_sql(from(p in Post, group_by: p.id, having: avg(p.views) > ^5), actual)
    end

    test "an aggregate under :having on an explicitly grouped query keeps that grouping" do
      source = from(p in Post, group_by: p.author_id)
      actual = CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])
      assert_sql(from(p in Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
    end
  end

  describe ":aggregate wrapper (alias of shorthand form)" do
  @describetag feature: :aggregate_operators
    test "the short aggregate spelling works (gt spelling, end-to-end)" do
      source = from(p in Post, group_by: p.author_id)

      actual =
        CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])

      assert_sql(from(p in Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
    end

    test "the :aggregate wrapper produces the same HAVING query as the shorthand spelling (map params)" do
      source = from(p in Post, group_by: p.author_id)

      shorthand =
        CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{>: 5}}}}, [])

      wrapper =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}},
          []
        )

      assert_sql(shorthand, wrapper)
    end

    test "the :aggregate wrapper accepts keyword list params" do
      source = from(p in Post, group_by: p.author_id)

      shorthand =
        CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{>: 5}}}}, [])

      wrapper =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{aggregate: [fn: :avg, compare: :>, value: 5]}}},
          []
        )

      assert_sql(shorthand, wrapper)
    end
  end

  # ---- merged from comparison_operators (schemaless) ----
  describe "comparison operators (schemaless)" do
    @describetag feature: :comparison_operators
    @describetag schema_mode: :schemaless
    test "matches records where the field equals the value using ==" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{==: 1}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field equals the value using a plain map value" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: 1}, [])

      assert_query(expected, q2)
    end
  end

  # ---- merged from negation (schemaless) ----
  describe "negation (schemaless)" do
    @describetag feature: :negation
    @describetag schema_mode: :schemaless
    test "excludes records where the field is not in the given list" do
      expected =
        from(p in "posts", where: p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end
  end

  # ---- merged from string_matching (schemaless) ----
  describe "string matching (schemaless)" do
    @describetag feature: :string_matching
    @describetag schema_mode: :schemaless
    test "matches records where the field contains the text using like" do
      expected = from(p in "posts", where: like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{like: "hello"}}, [])

      assert_query(expected, q2)
    end
  end

  # ---- merged from string_transformations (schemaless) ----
  describe "string transformations (schemaless)" do
    @describetag feature: :string_transformations
    @describetag schema_mode: :schemaless
    test "matches records by comparing the lowercased field to the value" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) == ^"hello")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{==: %{lower: "hello"}}}, [])

      assert_query(expected, q2)
    end
  end

  # ---- merged from aggregate_operators (schemaless) ----
  describe "aggregate operators (schemaless)" do
    @describetag feature: :aggregate_operators
    @describetag schema_mode: :schemaless
    test "avg views greater than" do
      # A schemaless source has no primary key to group by, so the aggregate
      # lands in HAVING without an auto GROUP BY.
      expected = from(p in "posts", having: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{>: 10}}}, [])

      assert_query(expected, actual)
    end
  end
end
