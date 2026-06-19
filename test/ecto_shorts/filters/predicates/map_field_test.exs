defmodule EctoShorts.CommonFilters.MapFieldTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :map_field

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.UserData

  import Ecto.Query

  describe "bare :map field (UserData.data)" do
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
