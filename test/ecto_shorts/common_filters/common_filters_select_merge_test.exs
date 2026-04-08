defmodule EctoShorts.CommonFilters.SelectMergeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "select_merge shapes" do
    test "matches Ecto.Query for a root select_merge map tuple alias mapping" do
      source = from(p in Post, select: %{})

      expected =
        from(p in Post,
          select: %{},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: {:map, %{post_title: :title}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding select_merge alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{}
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{},
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                select_merge: %{author_name: :first_name}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding select_merge alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          select: %{}
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: %{},
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                select_merge: %{author_name: :first_name}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "accepts a DynamicExpr value in a keyword-list select_merge" do
      dyn = dynamic([p], p.views + ^0)
      source = from(p in Post, select: %{id: p.id})

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [extra_views: dyn]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "accepts a non-atom, non-dynamic value in a keyword-list select_merge" do
      source = from(p in Post, select: %{id: p.id})

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [label: "static_value"]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  # Covers select_merge.ex line 52: the `else` branch inside `apply_select_merge`
  # when `entries` is a list but not a keyword list. The non-keyword list is passed
  # as a whole to `select_merge_expr`. Ecto raises at query-build time because a
  # plain list is not a valid select_merge expression; the line is still covered
  # because it executes before the exception.
  describe "select_merge non-keyword list" do
    test "covers the non-keyword list branch via select_merge_expr" do
      source = from(p in Post, select: %{})

      assert_raise Ecto.QueryError, fn ->
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [:id, :title]},
          []
        )
      end
    end
  end

  # Covers select_merge.ex line 90 (reduce_params catch-all): when a keyword-list
  # entry has an atom alias but a non-atom, non-DynamicExpr value (e.g. an integer),
  # the catch-all branch calls select_merge_expr with the raw value.
  describe "select_merge non-atom field value in keyword list" do
    test "passes a non-atom non-dynamic value through select_merge_expr" do
      source = from(p in Post, select: %{})
      expected = select_merge(source, [], %{post_count: ^42})

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [post_count: 42]},
          []
        )

      assert_query(expected, actual)
    end
  end

  # Covers select_merge.ex line 78: apply_select_merge/5 catch-all when the
  # top-level select_merge value is not a map, list, or tuple. A DynamicExpr
  # (struct) falls through all earlier guards and reaches line 78, which calls
  # Query.select_merge(query, ^value). Ecto then raises because a DynamicExpr
  # cannot be merged into a %{} select; line 78 is still covered.
  describe "select_merge catch-all with DynamicExpr value" do
    test "covers the catch-all apply_select_merge clause with a bare DynamicExpr" do
      source = from(p in Post, select: %{})
      dyn = dynamic([p], p.id)

      assert_raise Ecto.QueryError, fn ->
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: dyn},
          []
        )
      end
    end
  end
end
