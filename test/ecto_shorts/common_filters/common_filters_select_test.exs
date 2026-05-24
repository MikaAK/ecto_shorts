defmodule EctoShorts.CommonFilters.SelectTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "select shapes" do
    test "matches Ecto.Query for a root select struct projection" do
      expected = from(p in Post, select: struct(p, [:id, :title]))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: {:struct, [:id, :title]}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding select field" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: a.first_name
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                select: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding select map alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                select: %{author_name: :first_name}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # `:first` and `:last` are positional aliases valid only inside the `at:` map.
    # `:first` resolves to binding index 1 (the root binding); `:last` resolves to
    # the highest binding index in the query.
    test "matches Ecto.Query for a first positional binding select alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: p.title
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              first: %{
                select: :title
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a last positional binding select alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          join: c in assoc(p, :comments)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          join: c in assoc(p, :comments),
          select: c.body
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              last: %{
                select: :body
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "select extended shapes" do
    test "matches Ecto.Query for a root select map with a plain keyword alias list" do
      expected =
        from(p in Post,
          select: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: [post_id: :id, post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select map with a plain map alias" do
      expected =
        from(p in Post,
          select: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: %{post_id: :id, post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select with a map alias" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select: %{author_name: :first_name}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select with a keyword alias list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select: [author_name: :first_name]}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select true (full binding)" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: a
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select: true}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select with struct projection" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: struct(a, [:first_name])
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select: {:struct, [:first_name]}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for positional binding select with atom field" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: field(a, ^field_name)
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{select: :first_name}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for positional binding select true (full binding)" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: a
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{select: true}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for positional binding select with struct projection" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: struct(a, [:first_name])
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{select: {:struct, [:first_name]}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "select_merge shapes" do
    test "matches Ecto.Query for root select_merge with a keyword alias list" do
      expected =
        from(p in Post,
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select_merge: [post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root select_merge with a map alias (single field)" do
      expected =
        from(p in Post,
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select_merge: %{post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root select_merge with a {alias, field} tuple" do
      expected =
        from(p in Post,
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select_merge: {:post_title, :title}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root select_merge with a dynamic expr alias" do
      dyn = dynamic([p], p.views * ^2)

      expected =
        from(p in Post,
          select_merge: %{doubled_views: ^dyn}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select_merge: {:doubled_views, dyn}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root select_merge with a literal value alias" do
      expected =
        from(p in Post,
          select_merge: %{constant: ^42}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select_merge: {:constant, 42}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select_merge with a keyword list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select_merge: [author_name: :first_name]}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding select_merge with a map alias" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{select_merge: %{author_name: :first_name}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "select map conversion paths" do
    test "matches Ecto.Query for root select with {:map, map} form" do
      expected =
        from(p in Post,
          select: map(p, [:id, :title])
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: {:map, [:id, :title]}},
          []
        )

      assert_query(expected, actual)
    end

    # Covers select.ex line 19-21: Map.to_list(params) when params is a plain map.
    # A plain map passed as {:map, map} is converted to a keyword list, then
    # apply_select_merge is called because it is a keyword list.
    test "matches Ecto.Query for root select with {:map, keyword_map} form" do
      expected =
        from(p in Post,
          select: %{post_id: p.id}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: {:map, %{post_id: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root select with a plain non-keyword list" do
      expected = from(p in Post, select: ^[:id, :title])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: [:id, :title]},
          []
        )

      assert_query(expected, actual)
    end

    # Covers select.ex line 67: apply_select/5 fallback when term is not a map,
    # list, boolean, or atom (e.g. a DynamicExpr struct). Passes the value
    # directly to Query.select via ^term.
    test "accepts a DynamicExpr as a select value" do
      dyn = dynamic([p], p.id)
      expected = from(p in Post, select: ^dyn)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{select: dyn},
          []
        )

      assert_query(expected, actual)
    end
  end
end
