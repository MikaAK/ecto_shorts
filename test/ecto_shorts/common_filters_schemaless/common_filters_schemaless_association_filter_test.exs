defmodule EctoShorts.CommonFilters.SchemalessAssociationFilterTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  # For a schemaless source, `association_key?/2` always returns false because
  # there is no schema to reflect on. A key that would trigger association
  # shorthand on a schema source is treated as a plain field equality filter
  # instead. To join on a related table, the caller must use the explicit
  # `:join` filter key.
  describe "unknown key with scalar value (schemaless)" do
    test "treats an unknown key with a scalar value as a plain field equality filter" do
      expected = from(p in "posts", where: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{author_id: 1},
          []
        )

      assert_query(expected, actual)
    end
  end
end
