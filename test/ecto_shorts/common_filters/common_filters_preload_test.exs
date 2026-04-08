defmodule EctoShorts.CommonFilters.PreloadTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "preload shapes" do
    test "matches Ecto.Query for a root preload atom" do
      expected = from(p in Post, preload: :author)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{preload: :author},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a nested preload keyword list" do
      expected = from(p in Post, preload: [comments: :author])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{preload: [comments: :author]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named join-backed preload" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          preload: [author: a]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                preload: :author
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named nested join-backed preload tuple" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          preload: [author: {a, [posts: :comments]}]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                preload: [author: [posts: :comments]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional nested join-backed preload tuple" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          preload: [author: {a, [posts: :comments]}]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                preload: [author: [posts: :comments]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "join-backed preload with where filters" do
    test "matches Ecto.Query for a join-backed preload with no filter on the binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          preload: [comments: c]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                preload: :comments
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a join-backed preload with a where filter on the same binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          where: c.published == ^true,
          preload: [comments: c]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                where: %{published: true},
                preload: :comments
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # Each `as:` entry dispatches its `preload:` independently against its own binding
    # variable. Two separate named-binding preload operations cannot be merged into a single
    # `{binding, nested_spec}` tuple. Two independent `preload:` clauses are emitted;
    # Ecto merges them at load time. To use a second join variable as the nested loader,
    # the caller must build the combined tuple manually before calling this API.
    test "emits two independent preload clauses when two named bindings each declare a preload" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          join: a in assoc(c, :author),
          as: :comment_author
        )

      base_expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          join: a in assoc(c, :author),
          as: :comment_author,
          where: c.published == ^true,
          preload: [comments: [author: []]],
          preload: [author: a]
        )

      expected = from([p, c] in base_expected, preload: [comments: c])

      # A keyword list is used for `as:` to guarantee iteration order so the
      # resulting preload clause key order is deterministic across runs.
      actual =
        CommonFilters.convert_params_to_filter(
          source,
          [
            as: [
              comment_author: [preload: :author],
              comments: [where: %{published: true}, preload: [comments: [author: []]]]
            ]
          ],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a through-association preload with a root-level where filter" do
      expected =
        from(p in Post,
          where: p.title == ^"hello",
          preload: [:comments_authors]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            where: %{title: "hello"},
            preload: :comments_authors
          },
          []
        )

      assert_query(expected, actual)
    end

    # A top-level `preload:` key and a binding-scoped `preload:` for the same association
    # both fire independently, producing two separate preload clauses. The top-level path
    # dispatches through the unbound `build_preload/2` path and issues a separate Ecto
    # query for the nested association. The binding-scoped path uses the join variable.
    # When a join exists, use only the binding-scoped `preload:` and omit the top-level key.
    test "emits two preload clauses when a top-level preload and a binding-scoped preload target the same association" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          where: c.published == ^true,
          preload: [comments: [:author]],
          preload: [comments: c]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            preload: [comments: :author],
            as: %{
              comments: %{
                where: %{published: true},
                preload: :comments
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a join-backed nested preload tuple with a where filter on the binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          where: c.published == ^true,
          preload: [comments: {c, [post: []]}]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                where: %{published: true},
                preload: [comments: [post: []]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional at: binding with a where filter and preload" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments)
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          where: c.published == ^true,
          preload: [comments: c]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                where: %{published: true},
                preload: :comments
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a join-backed preload with a select on the same binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          select: c.body,
          preload: [comments: c]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                preload: :comments,
                select: :body
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # Passing a non-keyword list as the nested preload spec inside a binding-scoped
    # preload keyword entry produces a double-wrapped result. `normalize_preload/1`
    # returns a non-keyword list unchanged, and the tuple path in `build_preload/4`
    # then wraps it as the nested spec, producing `{binding, [list]}` instead of
    test "accepts a map input for preload under a named binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                preload: %{comments: :author}
              }
            }
          },
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "handles bare atom preload key (nil nested) under a named binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                preload: [:author]
              }
            }
          },
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "normalizes a map nested preload spec under a named binding" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                preload: [comments: %{author: :post}]
              }
            }
          },
          []
        )

      assert %Ecto.Query{} = actual
    end

    # `{binding, list}`. Use a keyword list with atom keys for nested sub-associations:
    # `[comments: [author: [], post: []]]` rather than `[comments: [:author, :post]]`.
    test "produces a double-wrapped preload tuple when a non-keyword list is the nested spec" do
      source =
        from(p in Post,
          join: c in assoc(p, :comments),
          as: :comments
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              comments: %{
                where: %{published: true, replies: %{>: 0}},
                preload: [comments: [:author, :post]]
              }
            }
          },
          []
        )

      # The `from` macro normalizes `[[:author, :post]]` back to `[:author, :post]` so
      # a from-built expected cannot represent this structure. Assert on the raw field.
      assert [preload_clause] = actual.preloads
      assert {:comments, [[:author, :post]]} = preload_clause
    end
  end
end
