defmodule EctoShorts.DynamicBuilders.Postgres.CommonExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres.CommonExpr
  alias EctoShorts.Schema.Post

  import Ecto.Query

  test "dynamic_expr/4 builds a root named-binding expression" do
    expected = dynamic([q], field(q, :id) in ^[1, 2])
    actual = CommonExpr.dynamic_expr({:as, nil}, :ids, nil, [1, 2], [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/4 builds a named-binding alias expression" do
    date = ~U[2026-03-09 02:04:01.573399Z]
    expected = from(p in Post, as: :post, where: p.inserted_at >= ^date)

    actual =
      from(p in Post,
        as: :post,
        where: ^CommonExpr.dynamic_expr({:as, :post}, :start_date, nil, date, [])
      )

    assert_sql(expected, actual)
  end

  test "dynamic_expr/4 builds a positional-binding expression" do
    expected = dynamic([_, q], field(q, :id) < ^10)
    actual = CommonExpr.dynamic_expr({:at, 2}, :before, nil, 10, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/4 handles binding-selector calls directly" do
    expected = CommonExpr.dynamic_expr({:at, 2}, :before, nil, 10, [])
    actual = CommonExpr.dynamic_expr({:at, 2}, :before, nil, 10, [])

    assert_dynamic(expected, actual)
  end

  test "unknown keys return nil" do
    assert is_nil(CommonExpr.dynamic_expr({:as, nil}, :missing, nil, 1, []))
  end

  test "dynamic_expr/5 builds after expression (id >)" do
    expected = dynamic([q], field(q, :id) > ^5)
    actual = CommonExpr.dynamic_expr({:as, nil}, :after, nil, 5, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds since expression (id >=)" do
    expected = dynamic([q], field(q, :id) >= ^5)
    actual = CommonExpr.dynamic_expr({:as, nil}, :since, nil, 5, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds until expression (id <=)" do
    expected = dynamic([q], field(q, :id) <= ^5)
    actual = CommonExpr.dynamic_expr({:as, nil}, :until, nil, 5, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds end_date expression (inserted_at <=)" do
    date = ~U[2026-03-09 02:04:01.573399Z]
    expected = dynamic([q], field(q, :inserted_at) <= ^date)
    actual = CommonExpr.dynamic_expr({:as, nil}, :end_date, nil, date, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 builds until_date expression (inserted_at <=)" do
    date = ~U[2026-03-09 02:04:01.573399Z]
    expected = dynamic([q], field(q, :inserted_at) <= ^date)
    actual = CommonExpr.dynamic_expr({:as, nil}, :until_date, nil, date, [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 negates an expression with not" do
    expected = dynamic([q], field(q, :id) not in ^[1, 2])
    actual = CommonExpr.dynamic_expr({:as, nil}, :ids, :not, [1, 2], [])

    assert_dynamic(expected, actual)
  end

  test "dynamic_expr/5 returns nil for an unrecognised binding selector" do
    assert is_nil(CommonExpr.dynamic_expr(:unknown, :ids, nil, [1, 2], []))
  end
end
