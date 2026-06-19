defmodule EctoShorts.CommonFilters.TypedValueCastingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :typed_value_casting

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "typed predicate casting" do
    test "casts a string integer on a root schema field" do
      expected = from(p in Post, where: p.id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: "1"},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer for a named binding field" do
      source =
        from(p in Post,
          join: u in assoc(p, :author),
          as: :author
        )

      expected = where(source, [author: u], u.age == ^42)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{age: "42"}}},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer for a positional binding field" do
      source =
        from(p in Post,
          join: u in assoc(p, :author)
        )

      expected = where(source, [_, u], u.age == ^42)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{age: "42"}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "typed casting with comparison operators" do
    test "casts a string integer with the > operator" do
      expected = from(p in Post, where: p.views > ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{>: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the >= operator" do
      expected = from(p in Post, where: p.views >= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{>=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the < operator" do
      expected = from(p in Post, where: p.views < ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{<: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the <= operator" do
      expected = from(p in Post, where: p.views <= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{<=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the gt alias" do
      expected = from(p in Post, where: p.views > ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{gt: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the gte alias" do
      expected = from(p in Post, where: p.views >= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{gte: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the lt alias" do
      expected = from(p in Post, where: p.views < ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{lt: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the lte alias" do
      expected = from(p in Post, where: p.views <= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{lte: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the != operator" do
      expected = from(p in Post, where: p.views != ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the ne alias" do
      expected = from(p in Post, where: p.views != ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{ne: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the eq alias" do
      expected = from(p in Post, where: p.views == ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{eq: "10"}}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting for list membership" do
    test "casts a list of string integers for == operator" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{==: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a list of string integers for != operator" do
      expected = from(p in Post, where: p.views not in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a list of string integers for in operator" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{in: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a bare list of string integers as membership" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: ["10", "20"]}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting for array fields" do
    test "casts string elements in a list for array field equality" do
      expected = from(p in Post, where: p.tags == ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(Post, %{tags: %{==: ["elixir", "ecto"]}}, [])

      assert_query(expected, actual)
    end

    test "casts string elements in a list for array field inequality" do
      expected = from(p in Post, where: p.tags != ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: ["elixir", "ecto"]}}, [])

      assert_query(expected, actual)
    end

    test "casts string elements for array field in operator" do
      expected = from(p in Post, where: p.tags == ^["elixir"])

      actual = CommonFilters.convert_params_to_filter(Post, %{tags: ["elixir"]}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting with value wrapper" do
    test "casts a string integer inside a {:value, value} wrapper" do
      expected = from(p in Post, where: p.views > ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: {:value, "10"}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "typed casting for boolean fields" do
    test "casts a string boolean for equality" do
      expected = from(p in Post, where: p.published == ^true)

      actual = CommonFilters.convert_params_to_filter(Post, %{published: "true"}, [])

      assert_query(expected, actual)
    end
  end
end
