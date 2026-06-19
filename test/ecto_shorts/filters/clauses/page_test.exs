defmodule EctoShorts.CommonFilters.PageTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :page

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe ":page with index/size (offset-based)" do
    test "page 1, size 5 applies LIMIT 5 OFFSET 0" do
      expected = from(p in Post, limit: ^5, offset: ^0)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{page: %{index: 1, size: 5}}, [])

      assert_query(expected, actual)
    end

    test "page 2, size 5 applies LIMIT 5 OFFSET 5" do
      expected = from(p in Post, limit: ^5, offset: ^5)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 5}}, [])

      assert_query(expected, actual)
    end

    test "page 3, size 10 applies LIMIT 10 OFFSET 20" do
      expected = from(p in Post, limit: ^10, offset: ^20)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{page: %{index: 3, size: 10}}, [])

      assert_query(expected, actual)
    end

    test "respects named binding selector" do
      source = from(p in Post, join: u in assoc(p, :author), as: :author)
      expected = source |> limit([author: u], ^5) |> offset([author: u], ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{page: %{index: 1, size: 5}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "respects positional binding selector" do
      source = from(p in Post, join: u in assoc(p, :author))
      expected = source |> limit([_, u], ^5) |> offset([_, u], ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{page: %{index: 1, size: 5}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe ":page with index/size string casting" do
    test "casts string index and size to integers" do
      expected = from(p in Post, limit: ^10, offset: ^10)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{page: %{index: "2", size: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts string size only" do
      expected = from(p in Post, limit: ^5, offset: ^0)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{page: %{index: 1, size: "5"}}, [])

      assert_query(expected, actual)
    end
  end

  describe ":page with after cursor (keyset forward)" do
    test "after: id, by: :id, size: 10 applies WHERE id > cursor ORDER BY id ASC LIMIT 10" do
      expected = from(p in Post, where: p.id > ^5, order_by: [asc: p.id], limit: ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{after: 5, by: :id, size: 10}},
          []
        )

      assert_sql(expected, actual)
    end

    test "after: nil applies ORDER BY id ASC LIMIT 10 with no WHERE" do
      expected = from(p in Post, order_by: [asc: p.id], limit: ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{after: nil, by: :id, size: 10}},
          []
        )

      assert_sql(expected, actual)
    end

    test "respects named binding selector" do
      source = from(p in Post, join: u in assoc(p, :author), as: :author)

      expected =
        source
        |> where([author: u], u.id > ^10)
        |> order_by([author: u], asc: u.id)
        |> limit(^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{page: %{after: 10, by: :id, size: 5}}}},
          []
        )

      assert_sql(expected, actual)
    end

    test "respects positional binding selector" do
      source = from(p in Post, join: u in assoc(p, :author))

      expected =
        source
        |> where([_, u], u.id > ^10)
        |> order_by([_, u], asc: u.id)
        |> limit(^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{page: %{after: 10, by: :id, size: 5}}}},
          []
        )

      assert_sql(expected, actual)
    end
  end

  describe ":page cursor pagination on non-id field" do
    test "after cursor on :views field applies WHERE views > cursor ORDER BY views ASC LIMIT" do
      expected = from(p in Post, where: p.views > ^100, order_by: [asc: p.views], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{after: 100, by: :views, size: 5}},
          []
        )

      assert_sql(expected, actual)
    end

    test "before cursor on :views field applies WHERE views < cursor ORDER BY views DESC LIMIT" do
      expected = from(p in Post, where: p.views < ^200, order_by: [desc: p.views], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{before: 200, by: :views, size: 5}},
          []
        )

      assert_sql(expected, actual)
    end

    test "casts string size in after-cursor shape" do
      expected = from(p in Post, where: p.id > ^5, order_by: [asc: p.id], limit: ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{after: 5, by: :id, size: "10"}},
          []
        )

      assert_sql(expected, actual)
    end
  end

  describe ":page with before cursor (keyset backward)" do
    test "before: id, by: :id, size: 5 applies WHERE id < cursor ORDER BY id DESC LIMIT 5" do
      expected = from(p in Post, where: p.id < ^10, order_by: [desc: p.id], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{before: 10, by: :id, size: 5}},
          []
        )

      assert_sql(expected, actual)
    end

    test "before: nil applies ORDER BY id DESC LIMIT 5 with no WHERE" do
      expected = from(p in Post, order_by: [desc: p.id], limit: ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{page: %{before: nil, by: :id, size: 5}},
          []
        )

      assert_sql(expected, actual)
    end

    test "respects named binding selector" do
      source = from(p in Post, join: u in assoc(p, :author), as: :author)

      expected =
        source
        |> where([author: u], u.id < ^10)
        |> order_by([author: u], desc: u.id)
        |> limit(^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{page: %{before: 10, by: :id, size: 5}}}},
          []
        )

      assert_sql(expected, actual)
    end

    test "respects positional binding selector" do
      source = from(p in Post, join: u in assoc(p, :author))

      expected =
        source
        |> where([_, u], u.id < ^10)
        |> order_by([_, u], desc: u.id)
        |> limit(^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{page: %{before: 10, by: :id, size: 5}}}},
          []
        )

      assert_sql(expected, actual)
    end
  end
end
