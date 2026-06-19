defmodule EctoShorts.CommonFilters.ExceptTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :except

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "set operation shapes" do
    test "matches Ecto.Query for except with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when except is nil" do
      expected = from(p in Post)
      actual = CommonFilters.convert_params_to_filter(expected, %{except: nil}, [])
      assert_query(expected, actual)
    end
  end
end
