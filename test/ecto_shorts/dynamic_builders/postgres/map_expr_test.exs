defmodule EctoShorts.DynamicBuilders.Postgres.MapExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres.MapExpr

  import Ecto.Query

  describe "nil checks" do
    test "nil value produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :data)))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, nil, [])

      assert_dynamic(expected, actual)
    end

    test "{:==, nil} produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :data)))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:==, nil}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, nil} produces IS NOT NULL" do
      expected = dynamic([q], not is_nil(field(q, :data)))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:!=, nil}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "equality operators" do
    test "{:==, scalar} produces equality comparison" do
      expected = dynamic([q], field(q, :data) == ^~s({"key":"value"}))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:==, ~s({"key":"value"})}, [])

      assert_dynamic(expected, actual)
    end

    test "{:!=, scalar} produces inequality comparison" do
      expected = dynamic([q], field(q, :data) != ^~s({"key":"value"}))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:!=, ~s({"key":"value"})}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "JSONB containment operators" do
    test "{:contains, {key, value}} produces JSONB @> containment from a single-key tuple" do
      expected = dynamic([q], fragment("? @> ?::jsonb", field(q, :data), ^%{key: "value"}))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contains, {:key, "value"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:contains, raw_json_string} produces JSONB @> containment from a string" do
      expected = dynamic([q], fragment("? @> ?::jsonb", field(q, :data), ^~s({"key":"value"})))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contains, ~s({"key":"value"})}, [])

      assert_dynamic(expected, actual)
    end

    test "{:contains, list} produces JSONB @> containment from a list" do
      expected = dynamic([q], fragment("? @> ?::jsonb", field(q, :data), ^["a", "b"]))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contains, ["a", "b"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:contained_by, {key, value}} produces JSONB <@ from a single-key tuple" do
      expected = dynamic([q], fragment("? <@ ?::jsonb", field(q, :data), ^%{key: "value"}))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contained_by, {:key, "value"}}, [])

      assert_dynamic(expected, actual)
    end

    test "{:contained_by, raw_json_string} produces JSONB <@ from a string" do
      expected = dynamic([q], fragment("? <@ ?::jsonb", field(q, :data), ^~s({"key":"value"})))

      actual =
        MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contained_by, ~s({"key":"value"})}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "JSONB key existence operators" do
    test "{:has_key, key} produces jsonb_exists fragment" do
      expected = dynamic([q], fragment("jsonb_exists(?, ?)", field(q, :data), ^"name"))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:has_key, "name"}, [])

      assert_dynamic(expected, actual)
    end

    test "{:has_any_key, keys} produces jsonb_exists_any fragment" do
      expected = dynamic([q], fragment("jsonb_exists_any(?, ?)", field(q, :data), ^["k1", "k2"]))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:has_any_key, ["k1", "k2"]}, [])

      assert_dynamic(expected, actual)
    end

    test "{:has_all_keys, keys} produces jsonb_exists_all fragment" do
      expected = dynamic([q], fragment("jsonb_exists_all(?, ?)", field(q, :data), ^["k1", "k2"]))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:has_all_keys, ["k1", "k2"]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "negation" do
    test "negated {:contains, tuple} wraps the containment expression with NOT" do
      expected = dynamic([q], not fragment("? @> ?::jsonb", field(q, :data), ^%{key: "value"}))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, :not, {:contains, {:key, "value"}}, [])

      assert_dynamic(expected, actual)
    end

    test "negated {:has_key, key} wraps the exists expression with NOT" do
      expected = dynamic([q], not fragment("jsonb_exists(?, ?)", field(q, :data), ^"name"))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, :not, {:has_key, "name"}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "nil and error cases" do
    test "unrecognised operator returns nil" do
      assert nil == MapExpr.dynamic_expr({:as, nil}, :data, nil, {:unknown_op, "value"}, [])
    end
  end
end
