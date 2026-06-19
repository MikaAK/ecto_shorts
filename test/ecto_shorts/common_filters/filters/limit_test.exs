defmodule EctoShorts.CommonFilters.LimitTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :limit

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Limit
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "fallthrough binding" do
    test "applies limit with no binding when selector is unrecognized" do
      expected = limit(Post, ^5)
      q = from(p in Post)

      actual = Limit.build_query(:limit, Post, q, {:unknown_binding, :foo}, 5, [])

      assert_query(expected, actual)
    end
  end

  describe "limit shapes (schemaless)" do
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root integer limit" do
      expected = limit("posts", ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe ":first as a limit alias" do
    test "produces the same query as :limit" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{first: 10},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "limit shapes" do
    test "matches Ecto.Query for a root integer limit" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding limit payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author),
          as: :author
        )

      expected = limit(source, [author: u], ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                limit: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding limit payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author)
        )

      expected = limit(source, [_, u], ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                limit: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer limit payload" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{limit: "10"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
