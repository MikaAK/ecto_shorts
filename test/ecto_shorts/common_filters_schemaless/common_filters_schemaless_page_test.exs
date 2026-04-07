defmodule EctoShorts.CommonFilters.SchemalessPageTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe ":page with index/size (offset-based, schemaless)" do
    test "page 1, size 5 applies LIMIT 5 OFFSET 0" do
      expected = from(p in "posts", limit: ^5, offset: ^0)

      actual =
        CommonFilters.convert_params_to_filter("posts", %{page: %{index: 1, size: 5}}, [])

      assert_query(expected, actual)
    end

    test "page 2, size 5 applies LIMIT 5 OFFSET 5" do
      expected = from(p in "posts", limit: ^5, offset: ^5)

      actual =
        CommonFilters.convert_params_to_filter("posts", %{page: %{index: 2, size: 5}}, [])

      assert_query(expected, actual)
    end

    test "page 3, size 10 applies LIMIT 10 OFFSET 20" do
      expected = from(p in "posts", limit: ^10, offset: ^20)

      actual =
        CommonFilters.convert_params_to_filter("posts", %{page: %{index: 3, size: 10}}, [])

      assert_query(expected, actual)
    end
  end

  describe ":page with index/size string casting (schemaless)" do
    test "casts string index and size to integers" do
      expected = from(p in "posts", limit: ^10, offset: ^10)

      actual =
        CommonFilters.convert_params_to_filter("posts", %{page: %{index: "2", size: "10"}}, [])

      assert_query(expected, actual)
    end
  end

  describe ":page with after cursor (keyset forward, schemaless)" do
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

    test "after: nil applies ORDER BY id ASC LIMIT 10 with no WHERE" do
      expected = from(p in "posts", order_by: [asc: p.id], limit: ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{page: %{after: nil, by: :id, size: 10}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe ":page with before cursor (keyset backward, schemaless)" do
    test "before: id, by: :id, size: 5 applies WHERE id < cursor ORDER BY id DESC LIMIT 5" do
      expected = from(p in "posts", where: p.id < ^10, order_by: [desc: p.id], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{page: %{before: 10, by: :id, size: 5}},
          []
        )

      assert_query(expected, actual)
    end

    test "before: nil applies ORDER BY id DESC LIMIT 5 with no WHERE" do
      expected = from(p in "posts", order_by: [desc: p.id], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{page: %{before: nil, by: :id, size: 5}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
