defmodule EctoShorts.CommonFilters.Schemaless.ComparisonOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :comparison_operators

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "comparison operators (schemaless)" do
    test "matches records where the field equals the value using ==" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{==: 1}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field equals the value using a plain map value" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: 1}, [])

      assert_query(expected, q2)
    end
  end
end
