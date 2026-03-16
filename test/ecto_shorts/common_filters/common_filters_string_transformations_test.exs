defmodule EctoShorts.CommonFilters.StringTransformationsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "convert_params_to_filter/3 string transformations" do
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
end
