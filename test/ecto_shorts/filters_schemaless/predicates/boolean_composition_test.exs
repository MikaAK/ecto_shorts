defmodule EctoShorts.CommonFilters.Schemaless.BooleanCompositionTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :boolean_composition

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "boolean composition (schemaless)" do
    test ":and with a single field produces a where clause" do
      expected = from(p in "posts", where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{and: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":or with a single field produces an or_where clause" do
      expected = from(p in "posts", or_where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{or: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":or with a list of param maps reduces as or_where for each entry" do
      expected =
        from(p in "posts",
          or_where: p.views == ^15,
          or_where: p.views == ^20
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{or: [%{views: 15}, %{views: 20}]},
          []
        )

      assert_query(expected, actual)
    end

    test "keyword list where: entries AND together" do
      expected = from(p in "posts", where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [where: %{published: true}, where: %{views: 5}],
          []
        )

      assert_query(expected, actual)
    end
  end
end
