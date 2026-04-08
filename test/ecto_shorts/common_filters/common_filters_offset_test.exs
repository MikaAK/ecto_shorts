defmodule EctoShorts.CommonFilters.OffsetTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "offset shapes" do
    test "matches Ecto.Query for a root integer offset" do
      expected = offset(Post, ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{offset: 5},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding offset payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author),
          as: :author
        )

      expected = offset(source, [author: u], ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                offset: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding offset payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author)
        )

      expected = offset(source, [_, u], ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                offset: 5
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer offset payload" do
      expected = offset(Post, ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{offset: "5"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
