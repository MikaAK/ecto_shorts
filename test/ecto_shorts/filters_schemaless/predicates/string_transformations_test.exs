defmodule EctoShorts.CommonFilters.Schemaless.StringTransformationsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :string_transformations

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "string transformations (schemaless)" do
    test "matches records by comparing the lowercased field to the value" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) == ^"hello")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{==: %{lower: "hello"}}}, [])

      assert_query(expected, q2)
    end
  end
end
