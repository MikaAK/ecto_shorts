defmodule EctoShorts.CommonFilters.Schemaless.StringMatchingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :string_matching

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "string matching (schemaless)" do
    test "matches records where the field contains the text using like" do
      expected = from(p in "posts", where: like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{like: "hello"}}, [])

      assert_query(expected, q2)
    end
  end
end
