defmodule EctoShorts.DynamicBuilders.Postgres.MapExprTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres.MapExpr

  import Ecto.Query
  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.UserData


  describe "nil checks" do
    test "nil value produces IS NULL" do
      expected = dynamic([q], is_nil(field(q, :data)))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:==, nil}, [])

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

    test "unsupported binding selector returns nil via catch-all clause" do
      assert nil == MapExpr.dynamic_expr({:unsupported, :binding}, :data, nil, {:==, "v"}, [])
    end
  end

  describe "contained_by list form" do
    test "{:contained_by, list} produces JSONB <@ from a list" do
      expected = dynamic([q], fragment("? <@ ?::jsonb", field(q, :data), ^["a", "b"]))
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:contained_by, ["a", "b"]}, [])

      assert_dynamic(expected, actual)
    end
  end

  describe "plain value" do
    test "plain scalar value passed as {:==, value} produces equality" do
      expected = dynamic([q], field(q, :data) == ^"hello")
      actual = MapExpr.dynamic_expr({:as, nil}, :data, nil, {:==, "hello"}, [])

      assert_dynamic(expected, actual)
    end
  end

  # ---- merged from map_field (via CommonFilters pipeline) ----
  describe "bare :map field (UserData.data)" do
  @describetag feature: :map_field
    test "matches Ecto.Query for IS NULL" do
      expected = from(u in UserData, where: is_nil(u.data))
      actual = CommonFilters.convert_params_to_filter(UserData, %{data: nil}, [])

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for JSONB containment from a single-key map" do
      expected =
        from(u in UserData,
          where: fragment("? @> ?::jsonb", u.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{contains: %{role: "admin"}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for negated JSONB containment" do
      expected =
        from(u in UserData,
          where: not fragment("? @> ?::jsonb", u.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{not: %{contains: %{role: "admin"}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for jsonb_exists has_key" do
      expected =
        from(u in UserData,
          where: fragment("jsonb_exists(?, ?)", u.data, ^"role")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{has_key: "role"}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for jsonb_exists_any has_any_key" do
      expected =
        from(u in UserData,
          where: fragment("jsonb_exists_any(?, ?)", u.data, ^["role", "name"])
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{has_any_key: ["role", "name"]}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for jsonb_exists_all has_all_keys" do
      expected =
        from(u in UserData,
          where: fragment("jsonb_exists_all(?, ?)", u.data, ^["role", "name"])
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{has_all_keys: ["role", "name"]}},
          []
        )

      assert_query(expected, actual)
    end

    # Multi-key containment: Normalizer expands [k1: "a", k2: "b"] into two
    # separate entries, producing ANDed @> conditions per key-value pair.
    # Semantically equivalent to a single @> with all key-value pairs for JSONB
    # objects. A keyword list is used here (not a map) to guarantee insertion order.
    test "matches Ecto.Query for multi-key containment as ANDed conditions" do
      expected =
        from(u in UserData,
          where:
            fragment("? @> ?::jsonb", u.data, ^%{role: "admin"}) and
              fragment("? @> ?::jsonb", u.data, ^%{active: "true"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{data: %{contains: [role: "admin", active: "true"]}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "typed {:map, :string} field (UserData.typed_map)" do
  @describetag feature: :map_field
    test "matches Ecto.Query for JSONB containment on a typed map field" do
      expected =
        from(u in UserData,
          where: fragment("? @> ?::jsonb", u.typed_map, ^%{key: "value"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          UserData,
          %{typed_map: %{contains: %{key: "value"}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for IS NULL on a typed map field" do
      expected = from(u in UserData, where: is_nil(u.typed_map))
      actual = CommonFilters.convert_params_to_filter(UserData, %{typed_map: nil}, [])

      assert_query(expected, actual)
    end
  end
end
