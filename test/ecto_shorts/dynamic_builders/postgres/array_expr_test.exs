defmodule EctoShorts.DynamicBuilders.Postgres.ArrayExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres
  alias EctoShorts.DynamicBuilders.Postgres.ArrayExpr

  import Ecto.Query

  describe "equality and membership" do
    test "list value produces array equality" do
      expected = dynamic([q], field(q, :tags) == ^["elixir", "erlang"])
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, ["elixir", "erlang"]}, [])

      assert_dynamic(expected, actual)
    end

    test "list value with != produces array inequality" do
      expected = dynamic([q], field(q, :tags) != ^["elixir", "erlang"])
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, ["elixir", "erlang"]}, [])

      assert_dynamic(expected, actual)
    end

    test "scalar value produces array membership (element in array)" do
      expected = dynamic([q], ^"elixir" in field(q, :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:in, "elixir"}, [])

      assert_dynamic(expected, actual)
    end

    test "nil value produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, nil} produces IS NOT NULL" do
      expected = dynamic([q], not is_nil(field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:in, list} produces array overlap fragment" do
      expected = dynamic([q], fragment("? && ?", field(q, :tags), ^["elixir", "erlang"]))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:in, ["elixir", "erlang"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, scalar} produces element-in-array membership" do
      expected = dynamic([q], ^"elixir" in field(q, :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, "elixir"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:overlaps, list} produces array overlap fragment" do
      expected = dynamic([q], fragment("? && ?", field(q, :tags), ^["a", "b"]))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:overlaps, ["a", "b"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, scalar} produces element-not-in-array membership" do
      expected = dynamic([q], ^"elixir" not in field(q, :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, "elixir"}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "count expressions" do
    test "{:count, {:==, 0}} produces coalesced array_length equals zero" do
      expected = dynamic([q], fragment("coalesce(array_length(?, 1), 0)", field(q, :tags)) == ^0)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:==, 0}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:==, n}} produces array_length equals n" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) == ^3)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:==, 3}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:!=, n}} produces array_length not-equal" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) != ^3)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:!=, 3}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:>, n}} produces array_length greater-than" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) > ^0)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:>, 0}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:>=, n}} produces array_length greater-than-or-equal" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) >= ^3)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:>=, 3}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:<, n}} produces array_length less-than" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) < ^3)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:<, 3}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:count, {:<=, n}} produces array_length less-than-or-equal" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) <= ^3)
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:<=, 3}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "ANY comparisons" do
    test "{:>, scalar} produces ANY greater-than fragment" do
      expected = dynamic([q], fragment("? < ANY(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:>, "a"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>=, scalar} produces ANY greater-than-or-equal fragment" do
      expected = dynamic([q], fragment("? <= ANY(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:>=, "a"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, scalar} produces ANY less-than fragment" do
      expected = dynamic([q], fragment("? > ANY(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<, "a"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, scalar} produces ANY less-than-or-equal fragment" do
      expected = dynamic([q], fragment("? >= ANY(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<=, "a"}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "ALL comparisons" do
    test "{:all, {:>: scalar}} produces ALL greater-than fragment" do
      expected = dynamic([q], fragment("? < ALL(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:>, "a"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, {:>=, scalar}} produces ALL greater-than-or-equal fragment" do
      expected = dynamic([q], fragment("? <= ALL(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:>=, "a"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, {:<, scalar}} produces ALL less-than fragment" do
      expected = dynamic([q], fragment("? > ALL(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:<, "a"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, {:<=, scalar}} produces ALL less-than-or-equal fragment" do
      expected = dynamic([q], fragment("? >= ALL(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:<=, "a"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, {:in, list}} produces array containment fragment" do
      expected = dynamic([q], fragment("? <@ ?", field(q, :tags), ^["elixir", "erlang"]))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:in, ["elixir", "erlang"]}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, op_value_tuple} produces ALL comparison from plain tuple payload" do
      expected = dynamic([q], fragment("? < ALL(?)", ^"a", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:>, "a"}}, [])
      assert_dynamic(expected, actual)
    end

    test "{:all, [bare_scalar]} returns nil (non-op bare value not supported)" do
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, ["elixir"]}, [])
      assert is_nil(actual)
    end

    test "{:all, {:==, scalar}} produces ALL equality fragment" do
      expected = dynamic([q], fragment("? = ALL(?)", ^"elixir", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:==, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:all, {:!=, scalar}} produces ALL inequality fragment" do
      expected = dynamic([q], fragment("? != ALL(?)", ^"elixir", field(q, :tags)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:!=, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "string transform expressions" do
    test "{:==, {:lower, value}} produces unnest lower-equality fragment" do
      expected =
        dynamic(
          [q],
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
            field(q, :tags),
            ^"elixir"
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, {:lower, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, {:upper, value}} produces unnest upper-equality fragment" do
      expected =
        dynamic(
          [q],
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
            field(q, :tags),
            ^"ELIXIR"
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, {:upper, "ELIXIR"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:lower, value}} produces unnest lower-inequality fragment" do
      expected =
        dynamic(
          [q],
          fragment(
            "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
            field(q, :tags),
            ^"elixir"
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, {:lower, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:upper, value}} produces unnest upper-inequality fragment" do
      expected =
        dynamic(
          [q],
          fragment(
            "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
            field(q, :tags),
            ^"ELIXIR"
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, {:upper, "ELIXIR"}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "LIKE / ILIKE pattern matching" do
    test "{:like, list} produces LIKE ANY unnest fragment with auto-wrapped patterns" do
      patterns = ["%elixir%", "%erlang%"]

      expected =
        dynamic(
          [q],
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))",
            field(q, :tags),
            ^patterns
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:like, ["elixir", "erlang"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:like, list} preserves caller-supplied wildcard patterns" do
      patterns = ["elixir%", "%lang"]

      expected =
        dynamic(
          [q],
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))",
            field(q, :tags),
            ^patterns
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:like, ["elixir%", "%lang"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:like, non_binary_scalar} wraps non-binary scalar with percent signs" do
      patterns = ["%42%"]

      expected =
        dynamic(
          [q],
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))",
            field(q, :tags),
            ^patterns
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:like, 42}, [])
      assert_dynamic(expected, actual)
    end

    test "negation with {:ilike, pattern} produces negated ILIKE ANY fragment" do
      patterns = ["%elixir%"]

      expected =
        dynamic(
          [q],
          not fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))",
            field(q, :tags),
            ^patterns
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, :not, {:ilike, "elixir"}, [])

      assert_dynamic(expected, actual)
    end

    test "negation with {:ilike, wildcard} preserves caller-supplied wildcard patterns" do
      patterns = ["elixir%"]

      expected =
        dynamic(
          [q],
          not fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))",
            field(q, :tags),
            ^patterns
          )
        )

      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, :not, {:ilike, "elixir%"}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe ":value wrapper" do
    test "{:==, {:value, scalar}} dispatches as element membership" do
      expected = dynamic([q], ^"elixir" in field(q, :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, {:value, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:value, scalar}} dispatches as element not-in-array" do
      expected = dynamic([q], ^"elixir" not in field(q, :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, {:value, "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:value, scalar}} dispatches as ANY greater-than" do
      expected = dynamic([q], fragment("? < ANY(?)", ^5, field(q, :scores)))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :scores, nil, {:>, {:value, 5}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe ":any subquery quantifier" do
    test "{:==, {:any, subquery}} produces field == any(subquery)" do
      sub = from(p in "posts", select: p.score)
      expected = dynamic([q], field(q, :score) == any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:==, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:any, subquery}} produces field != any(subquery)" do
      sub = from(p in "posts", select: p.score)
      expected = dynamic([q], field(q, :score) != any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:!=, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:any, subquery}} produces field > any(subquery)" do
      sub = from(p in "posts", select: p.score)
      expected = dynamic([q], field(q, :score) > any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:>, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe ":parent_as cross-binding reference" do
    test "{:parent_as, {binding, field}} produces field == parent_as field" do
      expected = dynamic([q], field(q, :tags) == field(parent_as(:post), :tags))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:parent_as, {:post, :tags}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, {:parent_as, {binding, field}}} produces equality" do
      expected = dynamic([q], field(q, :tags) == field(parent_as(:post), :tags))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, {:parent_as, {:post, :tags}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, {:parent_as, {binding, field}}} produces inequality" do
      expected = dynamic([q], field(q, :tags) != field(parent_as(:post), :tags))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, {:parent_as, {:post, :tags}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:>, {:parent_as, {binding, field}}} produces greater-than" do
      expected = dynamic([q], field(q, :score) > field(parent_as(:post), :min_score))

      actual =
        ArrayExpr.dynamic_expr(
          {:as, nil},
          :score,
          nil,
          {:>, {:parent_as, {:post, :min_score}}},
          []
        )

      assert_dynamic(expected, actual)
    end
  end

  describe ":elements wrapper routes to ArrayExpr for schemaless sources" do
    test ":in list produces array overlap regardless of schema" do
      expected = dynamic([q], fragment("? && ?", field(q, :tags), ^["elixir", "ecto"]))

      actual =
        Postgres.build_dynamic(
          "posts",
          {:as, nil},
          {:tags, %{elements: %{in: ["elixir", "ecto"]}}},
          []
        )

      assert_dynamic(expected, actual)
    end

    test "scalar value produces element membership" do
      expected = dynamic([q], ^"elixir" in field(q, :tags))
      actual = Postgres.build_dynamic("posts", {:as, nil}, {:tags, %{elements: "elixir"}}, [])

      assert_dynamic(expected, actual)
    end

    test "nil produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :tags)))
      actual = Postgres.build_dynamic("posts", {:as, nil}, {:tags, %{elements: nil}}, [])

      assert_dynamic(expected, actual)
    end

    test "count with > produces array_length comparison" do
      expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) > ^3)

      actual =
        Postgres.build_dynamic("posts", {:as, nil}, {:tags, %{elements: %{count: %{>: 3}}}}, [])

      assert_dynamic(expected, actual)
    end

    test "count == 0 uses coalesce" do
      expected = dynamic([q], fragment("coalesce(array_length(?, 1), 0)", field(q, :tags)) == ^0)

      actual =
        Postgres.build_dynamic("posts", {:as, nil}, {:tags, %{elements: %{count: %{==: 0}}}}, [])

      assert_dynamic(expected, actual)
    end

    test "list value produces array equality" do
      expected = dynamic([q], field(q, :tags) == ^["elixir", "erlang"])

      actual =
        Postgres.build_dynamic(
          "posts",
          {:as, nil},
          {:tags, %{elements: ["elixir", "erlang"]}},
          []
        )

      assert_dynamic(expected, actual)
    end
  end

  describe "nil and error cases" do
    test "unsupported operator returns nil" do
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:unsupported_op, "value"}, [])
      assert is_nil(actual)
    end

    test "unrecognized binding selector returns nil" do
      actual = ArrayExpr.dynamic_expr({:bad_selector, :tags}, :tags, nil, "elixir", [])
      assert is_nil(actual)
    end
  end

  describe "unsupported operators log a warning and return nil" do
    import ExUnit.CaptureLog

    for op <- [:avg, :sum, :max, :min] do
      test "#{op} aggregate logs a warning" do
        log =
          capture_log(fn ->
            result = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {unquote(op), %{>: 0}}, [])
            assert is_nil(result)
          end)

        assert log =~ "#{unquote(op)}"
        assert log =~ "not supported"
      end
    end

    test ":any subquery quantifier logs a warning" do
      log =
        capture_log(fn ->
          result = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:any, []}, [])
          assert is_nil(result)
        end)

      assert log =~ ":any"
      assert log =~ "not supported"
    end

    test ":datetime logs a warning" do
      log =
        capture_log(fn ->
          result =
            ArrayExpr.dynamic_expr(
              {:as, nil},
              :tags,
              nil,
              {:datetime, {:ago, [count: 1, interval: "day"]}},
              []
            )

          assert is_nil(result)
        end)

      assert log =~ "datetime"
      assert log =~ "not supported"
    end

    test ":date logs a warning" do
      log =
        capture_log(fn ->
          result =
            ArrayExpr.dynamic_expr(
              {:as, nil},
              :tags,
              nil,
              {:date, {:ago, [count: 1, interval: "day"]}},
              []
            )

          assert is_nil(result)
        end)

      assert log =~ "date"
      assert log =~ "not supported"
    end

    test "arithmetic comparison logs a warning" do
      log =
        capture_log(fn ->
          result =
            ArrayExpr.dynamic_expr(
              {:as, nil},
              :tags,
              nil,
              {:>, {:value, {:+, {{:field, :other}, {:value, 1}}}}},
              []
            )

          assert is_nil(result)
        end)

      assert log =~ "arithmetic"
      assert log =~ "not supported"
    end
  end

  describe ":any subquery quantifier - remaining comparison operators" do
    setup do
      sub = from(p in "posts", select: p.score)
      {:ok, sub: sub}
    end

    test "{:>=, {:any, subquery}} produces field >= any(subquery)", %{sub: sub} do
      expected = dynamic([q], field(q, :score) >= any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:>=, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, {:any, subquery}} produces field < any(subquery)", %{sub: sub} do
      expected = dynamic([q], field(q, :score) < any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:<, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:any, subquery}} produces field <= any(subquery)", %{sub: sub} do
      expected = dynamic([q], field(q, :score) <= any(sub))
      actual = ArrayExpr.dynamic_expr({:as, nil}, :score, nil, {:<=, {:any, sub}}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe ":parent_as cross-binding reference - remaining comparison operators" do
    test "{:>=, {:parent_as, {binding, field}}} produces >= comparison" do
      expected = dynamic([q], field(q, :tags) >= field(parent_as(:post), :tags))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:>=, {:parent_as, {:post, :tags}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<, {:parent_as, {binding, field}}} produces < comparison" do
      expected = dynamic([q], field(q, :tags) < field(parent_as(:post), :tags))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<, {:parent_as, {:post, :tags}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:<=, {:parent_as, {binding, field}}} produces <= comparison" do
      expected = dynamic([q], field(q, :tags) <= field(parent_as(:post), :tags))

      actual =
        ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<=, {:parent_as, {:post, :tags}}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:parent_as, invalid_payload} logs a warning and returns nil" do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          result =
            ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:parent_as, :not_a_pair}, [])

          assert is_nil(result)
        end)

      assert log =~ ":parent_as requires a {binding, field} payload"
    end
  end

  describe "normalize_all_payload edge cases" do
    alias EctoShorts.DynamicBuilders.Postgres.ArrayExpr

    test "collapse_all_payload returns single-entry payload unwrapped" do
      # {all: scalar} exercises the non-list, non-map normalize_all_payload fallback
      actual = ArrayExpr.dynamic_expr({:as, nil}, :scores, nil, {:all, {:==, "a"}}, [])

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test "normalize_all_payload with multiple entries returns nil (no dispatch clause for list payload)" do
      # Multiple entries collapse to a list form that has no dispatch_expr clause
      actual =
        ArrayExpr.dynamic_expr(
          {:as, nil},
          :scores,
          nil,
          {:all, [eq: "a", ne: "b"]},
          []
        )

      assert is_nil(actual)
    end

    test "normalize_all_payload pass-through for non-map non-list non-tuple payload returns nil" do
      # A bare atom payload passes through the catch-all normalize_all_payload clause
      # and then finds no matching dispatch_expr clause
      actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, :bare_atom}, [])
      assert is_nil(actual)
    end
  end
end
