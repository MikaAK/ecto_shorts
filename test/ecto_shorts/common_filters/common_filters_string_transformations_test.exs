defmodule EctoShorts.CommonFilters.StringTransformationsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "string transformations" do
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

    test "matches records by comparing the trimmed field to the value" do
      expected = from(p in Post, where: fragment("trim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{trim: "al"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the left-trimmed field to the value" do
      expected = from(p in Post, where: fragment("ltrim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{ltrim: "al"}}}, [])

      assert_sql(expected, q2)
    end

    test "matches records by comparing the right-trimmed field to the value" do
      expected = from(p in Post, where: fragment("rtrim(?)", p.title) == ^"al")
      q2 = CommonFilters.convert_params_to_filter(Post, %{title: %{eq: %{rtrim: "al"}}}, [])

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
