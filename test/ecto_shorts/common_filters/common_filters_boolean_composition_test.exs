defmodule EctoShorts.CommonFilters.BooleanCompositionTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "convert_params_to_filter/3 :and shapes" do
    test ":and map with a single field produces a where clause" do
      expected = from(p in Post, where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter(Post, %{and: %{views: 15}}, [])

      assert_sql(expected, actual)
    end

    test ":and map with a range produces two where conditions AND-joined" do
      expected = from(p in Post, where: p.views > ^10 and p.views < ^20)
      actual = CommonFilters.convert_params_to_filter(Post, %{and: %{views: [>: 10, <: 20]}}, [])

      assert_sql(expected, actual)
    end

    test ":and map with multiple fields produces all fields where-AND-joined" do
      expected = from(p in Post, where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{and: [published: true, views: 5]}, [])

      assert_sql(expected, actual)
    end

    # `:and`, `:where`, and plain field keys all produce equivalent AND-joined
    # where clauses.
    test ":and is equivalent to a plain field filter" do
      plain = CommonFilters.convert_params_to_filter(Post, %{views: 15}, [])
      via_and = CommonFilters.convert_params_to_filter(Post, %{and: %{views: 15}}, [])

      assert_sql(plain, via_and)
    end

    test ":and is equivalent to :where" do
      via_where = CommonFilters.convert_params_to_filter(Post, %{where: %{views: 15}}, [])
      via_and = CommonFilters.convert_params_to_filter(Post, %{and: %{views: 15}}, [])

      assert_sql(via_where, via_and)
    end
  end

  describe "convert_params_to_filter/3 :or shapes" do
    test ":or map with a single field produces an or_where clause" do
      expected = from(p in Post, or_where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter(Post, %{or: %{views: 15}}, [])

      assert_sql(expected, actual)
    end

    # Multiple predicates inside a single `:or` map are AND-merged into one `or_where`
    # clause. The `:or` key determines the clause type; the inner predicates combine
    # with AND, not OR.
    test ":or map with a range produces a single or_where with AND-merged conditions" do
      expected = from(p in Post, or_where: p.views < ^5 and p.views > ^10)
      actual = CommonFilters.convert_params_to_filter(Post, %{or: %{views: [<: 5, >: 10]}}, [])

      assert_sql(expected, actual)
    end

    test ":or is equivalent to :or_where for a single field" do
      via_or_where = CommonFilters.convert_params_to_filter(Post, %{or_where: %{views: 15}}, [])
      via_or = CommonFilters.convert_params_to_filter(Post, %{or: %{views: 15}}, [])

      assert_sql(via_or_where, via_or)
    end
  end

  describe "convert_params_to_filter/3 list-of-maps / list-of-keyword-lists" do
    test ":and with a list of maps applies each map as a separate where clause" do
      expected = from(p in Post, where: p.views == ^5, where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{and: [%{views: 5}, %{published: true}]},
          []
        )

      assert_sql(expected, actual)
    end

    test ":and with a list of keyword lists applies each entry as a separate where clause" do
      expected = from(p in Post, where: p.views == ^5, where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{and: [[views: 5], [published: true]]}, [])

      assert_sql(expected, actual)
    end

    test ":or with a list of maps applies each map as a separate or_where clause" do
      expected = from(p in Post, or_where: p.views == ^5, or_where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{or: [%{views: 5}, %{published: true}]}, [])

      assert_sql(expected, actual)
    end

    test ":or with a list of keyword lists applies each entry as a separate or_where clause" do
      expected = from(p in Post, or_where: p.views == ^5, or_where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{or: [[views: 5], [published: true]]}, [])

      assert_sql(expected, actual)
    end

    test ":where with a list of maps applies each map as a separate where clause" do
      expected = from(p in Post, where: p.views == ^5, where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{where: [%{views: 5}, %{published: true}]},
          []
        )

      assert_sql(expected, actual)
    end

    test ":or_where with a list of maps applies each map as a separate or_where clause" do
      expected = from(p in Post, or_where: p.views == ^5, or_where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{or_where: [%{views: 5}, %{published: true}]},
          []
        )

      assert_sql(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 keyword list compositions" do
    test "two where: entries AND together" do
      expected = from(p in Post, where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [where: %{published: true}, where: %{views: 5}],
          []
        )

      assert_sql(expected, actual)
    end

    test "two or_where: entries produce separate or_where clauses" do
      expected = from(p in Post, or_where: p.title == ^"A", or_where: p.title == ^"B")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [or_where: %{title: "A"}, or_where: %{title: "B"}],
          []
        )

      assert_sql(expected, actual)
    end

    test "where: followed by or_where: preserves order" do
      expected = from(p in Post, where: p.published == ^true, or_where: p.title == ^"X")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [where: %{published: true}, or_where: %{title: "X"}],
          []
        )

      assert_sql(expected, actual)
    end

    # A keyword list preserves declaration order. A map does not guarantee iteration
    # order, so keyword lists are required when clause ordering matters.
    test "multiple where: and multiple or_where: all applied in order" do
      expected =
        from(p in Post,
          where: p.published == ^true,
          where: p.views == ^0,
          or_where: p.title == ^"A",
          or_where: p.title == ^"B"
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [
            where: %{published: true},
            where: %{views: 0},
            or_where: %{title: "A"},
            or_where: %{title: "B"}
          ],
          []
        )

      assert_sql(expected, actual)
    end

    test "two :and groups in a keyword list compose as sequential where clauses" do
      expected = from(p in Post, where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [and: %{published: true}, and: %{views: 5}],
          []
        )

      assert_sql(expected, actual)
    end
  end
end
