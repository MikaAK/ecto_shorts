defmodule EctoShorts.DynamicBuilders.Postgres.CommonExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

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
            ^CommonExpr.dynamic_expr({:as, :post}, :inserted_at, nil, {:start_date, date}, [])
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

    test ":start_date builds `>=` over the given column (no hardcoded inserted_at)" do
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

    test ":end_date operator produces <= comparison on the given column" do
      date = ~U[2026-03-09 02:04:01.573399Z]
      expected = dynamic([q], field(q, :inserted_at) <= ^date)
      actual = CommonExpr.dynamic_expr({:as, nil}, :inserted_at, nil, {:end_date, date}, [])

      assert_dynamic(expected, actual)
    end

    test ":until_date operator produces <= comparison on the given column" do
      date = ~U[2026-03-09 02:04:01.573399Z]
      expected = dynamic([q], field(q, :inserted_at) <= ^date)
      actual = CommonExpr.dynamic_expr({:as, nil}, :inserted_at, nil, {:until_date, date}, [])

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
    test ":exists produces an exists(subquery) expression" do
      sub = from(p in Post, where: p.published == ^true)
      actual = CommonExpr.dynamic_expr({:as, nil}, nil, nil, {:exists, sub}, [])

      assert %Ecto.Query.DynamicExpr{} = actual
    end
  end
end
