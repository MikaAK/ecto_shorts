defmodule EctoShorts.CommonFilters.SchemalessInvalidSchemaFieldTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "invalid schema fields on schemaless sources" do
    test "keeps arbitrary fields in where filters" do
      expected = from(p in "posts", where: p.does_not_exist == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{does_not_exist: 1},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps arbitrary fields in select filters" do
      expected = from(p in "posts", select: p.does_not_exist)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: :does_not_exist},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps arbitrary fields in order_by filters" do
      expected = from(p in "posts", order_by: [asc: p.does_not_exist])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :does_not_exist},
          []
        )

      assert_query(expected, actual)
    end
  end
end
