defmodule EctoShorts.CommonFilters.SchemalessStringTransformationsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 string transformations (schemaless)" do
    test "matches records by comparing the lowercased field to the value" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) == ^"hello")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{==: %{lower: "hello"}}}, [])

      assert_query(expected, q2)
    end

    test "matches records by comparing the uppercased field to the value" do
      expected = from(p in "posts", where: fragment("upper(?)", p.title) == ^"HELLO")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{==: %{upper: "HELLO"}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the lowercased field equals the value" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) != ^"hello")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{!=: %{lower: "hello"}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the uppercased field equals the value" do
      expected = from(p in "posts", where: fragment("upper(?)", p.title) != ^"HELLO")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{!=: %{upper: "HELLO"}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the lowercased field matches using negated ==" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) != ^"hello")

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{not: %{==: %{lower: "hello"}}}},
          []
        )

      assert_query(expected, q2)
    end

    test "excludes records where the uppercased field matches using negated ==" do
      expected = from(p in "posts", where: fragment("upper(?)", p.title) != ^"HELLO")

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{title: %{not: %{==: %{upper: "HELLO"}}}},
          []
        )

      assert_query(expected, q2)
    end
  end
end
