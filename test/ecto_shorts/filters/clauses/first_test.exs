defmodule EctoShorts.CommonFilters.FirstTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :first

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "first shapes" do
    test "matches Ecto.Query for a root integer first" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{first: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding first payload" do
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
                first: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding first payload" do
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
                first: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer first payload" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{first: "10"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
