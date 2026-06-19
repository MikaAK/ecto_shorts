defmodule EctoShorts.CommonFilters.Schemaless.PageTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :page

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe ":page shapes (schemaless)" do
    test "page 1, size 5 applies LIMIT 5 OFFSET 0" do
      expected = from(p in "posts", limit: ^5, offset: ^0)

      actual =
        CommonFilters.convert_params_to_filter("posts", %{page: %{index: 1, size: 5}}, [])

      assert_query(expected, actual)
    end

    test "after: id, by: :id, size: 10 applies WHERE id > cursor ORDER BY id ASC LIMIT 10" do
      expected = from(p in "posts", where: p.id > ^5, order_by: [asc: p.id], limit: ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{page: %{after: 5, by: :id, size: 10}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
