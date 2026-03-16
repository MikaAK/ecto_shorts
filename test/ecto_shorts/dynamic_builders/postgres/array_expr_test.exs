defmodule EctoShorts.DynamicBuilders.Postgres.ArrayExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres.ArrayExpr

  import Ecto.Query

  test "dynamic_expr/5 builds array equality from a list value" do
    expected = dynamic([q], field(q, :tags) == ^["elixir", "erlang"])
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, ["elixir", "erlang"], [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds array inequality from a list value" do
    expected = dynamic([q], field(q, :tags) != ^["elixir", "erlang"])
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, ["elixir", "erlang"]}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds array membership from a scalar value" do
    expected = dynamic([q], ^"elixir" in field(q, :tags))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, "elixir", [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds an is_nil expression for a nil array value" do
    expected = dynamic([q], is_nil(field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, nil, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds array overlap from an explicit in-list payload" do
    expected = dynamic([q], fragment("? && ?", field(q, :tags), ^["elixir", "erlang"]))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:in, ["elixir", "erlang"]}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds an array count greater-than expression" do
    expected = dynamic([q], fragment("array_length(?, 1)", field(q, :tags)) > ^0)
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:>, 0}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds an array count equals-zero expression" do
    expected = dynamic([q], fragment("coalesce(array_length(?, 1), 0)", field(q, :tags)) == ^0)
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:count, {:==, 0}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ANY comparison for arrays" do
    expected = dynamic([q], fragment("? < ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:>, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ALL comparison for arrays from array-local all payloads" do
    expected = dynamic([q], fragment("? < ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, %{>: "a"}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds array containment for array-local all in payloads" do
    expected = dynamic([q], fragment("? <@ ?", field(q, :tags), ^["elixir", "erlang"]))

    actual =
      ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, %{in: ["elixir", "erlang"]}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds lower transform equality for arrays" do
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

  test "dynamic_expr/5 builds like-any pattern matching for arrays" do
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

  test "dynamic_expr/5 preserves caller-supplied like-any wildcard patterns for arrays" do
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

  test "dynamic_expr/5 builds upper transform equality for arrays" do
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

  test "dynamic_expr/5 builds lower transform inequality for arrays" do
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

  test "dynamic_expr/5 builds upper transform inequality for arrays" do
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

  test "dynamic_expr/5 builds scalar equality membership for arrays" do
    expected = dynamic([q], ^"elixir" in field(q, :tags))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:==, "elixir"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds scalar non-membership for arrays" do
    expected = dynamic([q], ^"elixir" not in field(q, :tags))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:!=, "elixir"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ALL >= comparison for arrays" do
    expected = dynamic([q], fragment("? <= ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, %{>=: "a"}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ALL < comparison for arrays" do
    expected = dynamic([q], fragment("? > ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, %{<: "a"}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ALL <= comparison for arrays" do
    expected = dynamic([q], fragment("? >= ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, %{<=: "a"}}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds >= ANY comparison for arrays" do
    expected = dynamic([q], fragment("? <= ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:>=, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds < ANY comparison for arrays" do
    expected = dynamic([q], fragment("? > ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds <= ANY comparison for arrays" do
    expected = dynamic([q], fragment("? >= ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:<=, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts eq alias for scalar array equality" do
    expected = dynamic([q], ^"elixir" in field(q, :tags))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:eq, "elixir"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts ne alias for scalar array non-membership" do
    expected = dynamic([q], ^"elixir" not in field(q, :tags))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:ne, "elixir"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts gt alias for array any greater-than" do
    expected = dynamic([q], fragment("? < ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:gt, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts gte alias for array any greater-than-or-equal" do
    expected = dynamic([q], fragment("? <= ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:gte, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts lt alias for array any less-than" do
    expected = dynamic([q], fragment("? > ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:lt, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 accepts lte alias for array any less-than-or-equal" do
    expected = dynamic([q], fragment("? >= ANY(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:lte, "a"}, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds negated ilike-any pattern matching for arrays" do
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

  test "dynamic_expr/5 returns nil for an unsupported array term" do
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:unsupported_op, "value"}, [])
    assert is_nil(actual)
  end

  test "dynamic_expr/5 returns nil when the binding selector does not match" do
    actual = ArrayExpr.dynamic_expr({:bad_selector, :tags}, :tags, nil, "elixir", [])
    assert is_nil(actual)
  end

  test "dynamic_expr/5 builds ALL comparison with a plain op-value tuple payload" do
    expected = dynamic([q], fragment("? < ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, {:>, "a"}}, [])
    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds ALL comparison with a list of op-value entries" do
    expected = dynamic([q], fragment("? < ALL(?)", ^"a", field(q, :tags)))
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, [{:>, "a"}]}, [])
    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 returns nil for all-payload with a single bare non-op value" do
    actual = ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:all, ["elixir"]}, [])
    assert is_nil(actual)
  end

  test "dynamic_expr/5 wraps a non-binary scalar pattern with percent signs" do
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

  test "dynamic_expr/5 preserves caller-supplied negated ilike wildcard patterns for arrays" do
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
