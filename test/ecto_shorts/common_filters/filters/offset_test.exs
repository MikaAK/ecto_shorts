defmodule EctoShorts.CommonFilters.OffsetTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :offset

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

    # Covers the fallback apply_offset/3 clause that builds Query.offset(query, ^expr)
    # without any binding list. This clause is reached when the selected_binding does
    # not match any of the generated patterns (root, named, or positional).
    test "applies offset via fallback when selected_binding is not a recognised pattern" do
      alias EctoShorts.CommonFilters.Offset

      query = from(p in Post)
      result = Offset.build_query(:offset, Post, query, :unrecognised_binding, 7, [])

      expected = offset(Post, ^7)
      assert_query(expected, result)
    end
  end
end
