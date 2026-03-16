defmodule EctoShorts.CommonFilters.SchemalessStringMatchingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 string matching (schemaless)" do
    test "matches records where the field contains the text using like" do
      expected = from(p in "posts", where: like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{like: "hello"}}, [])

      assert_query(expected, q2)
    end

    test "preserves caller-supplied wildcard patterns using like" do
      expected = from(p in "posts", where: like(p.title, ^"hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{like: "hello%"}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field contains the text case-insensitively using ilike" do
      expected = from(p in "posts", where: ilike(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{ilike: "hello"}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field matches any pattern in the like list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in "posts",
          where: fragment("? LIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter("posts", %{title: %{like: ["hello", "world"]}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field matches any pattern in the ilike list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in "posts",
          where: fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{ilike: ["hello", "world"]}},
          []
        )

      assert_query(expected, q2)
    end

    test "preserves caller-supplied wildcard patterns in the ilike list" do
      patterns = ["hello%", "%world"]

      expected =
        from(p in "posts",
          where: fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{ilike: ["hello%", "%world"]}},
          []
        )

      assert_query(expected, q2)
    end

    test "excludes records where the field contains the text using negated like" do
      expected = from(p in "posts", where: not like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{not: %{like: "hello"}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field contains the text using negated ilike" do
      expected = from(p in "posts", where: not ilike(p.title, ^"%hello%"))

      q2 =
        CommonFilters.convert_params_to_filter("posts", %{title: %{not: %{ilike: "hello"}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field matches any pattern in the negated like list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in "posts",
          where: not fragment("? LIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{not: %{like: ["hello", "world"]}}},
          []
        )

      assert_query(expected, q2)
    end

    test "excludes records where the field matches any pattern in the negated ilike list" do
      patterns = ["%hello%", "%world%"]

      expected =
        from(p in "posts",
          where: not fragment("? ILIKE ANY(?)", p.title, ^patterns)
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{not: %{ilike: ["hello", "world"]}}},
          []
        )

      assert_query(expected, q2)
    end
  end
end
