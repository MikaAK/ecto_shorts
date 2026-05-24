defmodule EctoShorts.CommonFilters.SchemalessTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  # -------------------------------------------------------------------
  # Unique schemaless behaviour: association keys treated as plain fields
  # -------------------------------------------------------------------

  describe "unknown key with scalar value (schemaless)" do
    # For a schemaless source, `association_key?/2` always returns false because
    # there is no schema to reflect on. A key that would trigger association
    # shorthand on a schema source is treated as a plain field equality filter
    # instead. To join on a related table, the caller must use the explicit
    # `:join` filter key.
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

  # -------------------------------------------------------------------
  # Unique schemaless behaviour: :elements wrapper forces ArrayExpr routing
  # -------------------------------------------------------------------

  describe ":elements wrapper (schemaless)" do
    test ":in with :elements produces array overlap (&&)" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["elixir", "ecto"]))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: %{in: ["elixir", "ecto"]}}},
          []
        )

      assert_query(expected, actual)
    end

    test ":in without :elements on schemaless source produces scalar IN" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{in: ["elixir", "ecto"]}},
          []
        )

      assert_query(expected, actual)
    end

    test "scalar value with :elements produces element membership" do
      expected = from(p in "posts", where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: "elixir"}},
          []
        )

      assert_query(expected, actual)
    end

    test "nil with :elements produces IS NULL" do
      expected = from(p in "posts", where: is_nil(p.tags))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: nil}},
          []
        )

      assert_query(expected, actual)
    end

    test "count with :elements produces array_length comparison" do
      expected = from(p in "posts", where: fragment("array_length(?, 1)", p.tags) > ^3)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: %{count: %{>: 3}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "list value with :elements produces array equality" do
      expected = from(p in "posts", where: p.tags == ^["elixir", "erlang"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: ["elixir", "erlang"]}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # -------------------------------------------------------------------
  # Unique schemaless behaviour: field_types: opt overrides type routing
  # -------------------------------------------------------------------

  describe "field_types: opt (schemaless)" do
    test "with field_types :map, has_key uses jsonb_exists" do
      expected =
        from(p in "data_stores",
          where: fragment("jsonb_exists(?, ?)", p.data, ^"role")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{has_key: "role"}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "with field_types :map, containment uses @>" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "without field_types, fields use scalar semantics regardless of name" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: ["elixir", "ecto"]},
          []
        )

      assert_query(expected, actual)
    end
  end

  # -------------------------------------------------------------------
  # Unique schemaless behaviour: arbitrary fields are always accepted
  # -------------------------------------------------------------------

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

  # -------------------------------------------------------------------
  # Smoke tests: confirm each filter type dispatches on schemaless sources
  # -------------------------------------------------------------------

  describe "comparison operators (schemaless)" do
    test "matches records where the field equals the value using ==" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{==: 1}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field equals the value using a plain map value" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: 1}, [])

      assert_query(expected, q2)
    end
  end

  describe "negation (schemaless)" do
    test "excludes records where the field is not in the given list" do
      expected =
        from(p in "posts", where: is_nil(p.published) or p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end
  end

  describe "string matching (schemaless)" do
    test "matches records where the field contains the text using like" do
      expected = from(p in "posts", where: like(p.title, ^"%hello%"))
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{like: "hello"}}, [])

      assert_query(expected, q2)
    end
  end

  describe "string transformations (schemaless)" do
    test "matches records by comparing the lowercased field to the value" do
      expected = from(p in "posts", where: fragment("lower(?)", p.title) == ^"hello")
      q2 = CommonFilters.convert_params_to_filter("posts", %{title: %{==: %{lower: "hello"}}}, [])

      assert_query(expected, q2)
    end
  end

  describe "aggregate operators (schemaless)" do
    test "avg views greater than" do
      expected = from(p in "posts", where: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{>: 10}}}, [])

      assert_query(expected, actual)
    end
  end

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

  describe "date wrappers (schemaless)" do
    test "inserted_at >= datetime_add 7 days using date wrapper" do
      expected =
        from(p in "posts",
          where:
            fragment("date(?)", p.inserted_at) >=
              fragment("date(?)", datetime_add(p.inserted_at, ^7, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{date: %{add: %{field: :inserted_at, count: 7, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "datetime wrappers (schemaless)" do
    test "matches records using datetime_add before comparison" do
      expected =
        from(p in "posts", where: p.inserted_at >= datetime_add(p.inserted_at, ^1, "day"))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{datetime: %{add: %{field: :inserted_at, count: 1, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "exclude shapes (schemaless)" do
    test "matches Ecto.Query for excluding where" do
      source = from(p in "posts", where: p.published == ^true)
      expected = exclude(source, :where)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :where},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding multiple fields with a list payload" do
      source =
        "posts"
        |> limit(^10)
        |> offset(^5)

      expected = exclude(source, [:limit, :offset])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: [:limit, :offset]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "join shapes (schemaless)" do
    test "matches Ecto.Query for a table join with on clause" do
      expected = from(p in "posts", join: u in "users", on: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [table: [source: "users", on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a table join with named binding" do
      expected =
        from(p in "posts",
          join: u in "users",
          as: :users,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [table: [source: "users", as: :users, on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "last shapes (schemaless)" do
    test "matches Ecto.Query for a root integer last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: 2},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal last wrapping after local filters" do
      expected =
        "posts"
        |> where([p], p.published == ^true)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [last: 2, published: true],
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "lock shapes (schemaless)" do
    test "matches Ecto.Query for a root for_update alias lock" do
      expected = lock("posts", "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{lock: %{name: :for_update}},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged for a direct raw string lock" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{lock: "FOR SHARE NOWAIT"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :lock value to be a map or keyword list with a :name key"
    end
  end

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

  describe "order modifier shapes (schemaless)" do
    test "matches Ecto.Query for a root order_by atom" do
      expected = from(p in "posts", order_by: [asc: :title])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for reverse_order after local order_by params" do
      expected =
        "posts"
        |> order_by([], asc: :title)
        |> reverse_order()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title, reverse_order: true},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "group_by shapes (schemaless)" do
    test "matches Ecto.Query for a root group_by atom" do
      expected = from(p in "posts", group_by: :author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{group_by: :author_id},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "having shapes (schemaless)" do
    test "matches Ecto.Query for a root aggregate having" do
      source = from(p in "posts", group_by: p.author_id)
      expected = from(p in "posts", group_by: p.author_id, having: avg(p.views) > ^100)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{avg: %{>: 100}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "select shapes (schemaless)" do
    test "matches Ecto.Query for a root select field atom" do
      expected = from(p in "posts", select: p.title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select map alias mapping" do
      expected =
        from(p in "posts",
          select: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: [post_id: :id, post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "select_merge shapes (schemaless)" do
    test "matches Ecto.Query for a root select_merge map alias mapping" do
      source = from(p in "posts", select: %{})

      expected =
        from(p in "posts",
          select: %{},
          select_merge: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: %{post_id: :id, post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "set operation shapes (schemaless)" do
    test "matches Ecto.Query for union with filter params" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = union("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{union: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "subquery shapes (schemaless)" do
    test "matches Ecto.Query for terminal subquery wrapping after local filters" do
      expected =
        "posts"
        |> order_by([], asc: :title)
        |> where([p], p.id == ^2)
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title, subquery: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "update shapes (schemaless)" do
    test "matches Ecto.Query for a root update set payload" do
      updates = [set: [title: "After"]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [set: [title: "After"]]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "with_cte shapes (schemaless)" do
    test "matches Ecto.Query for with_cte with filter params using the default source" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = with_cte("posts", "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: [published_posts: [as: [published: true]]]},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_cte params are invalid" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{with_cte: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params to be a map or keyword list"
    end
  end

  describe "with_named_binding shapes (schemaless)" do
    test "matches Ecto.Query for the documented with_named_binding workflow" do
      expected =
        from(p in "posts",
          join: u in "users",
          as: :users,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            with_named_binding: [
              users: %{join: [table: [source: "users", as: :users, on: %{author_id: 1}]]}
            ]
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "with_ties shapes (schemaless)" do
    test "matches Ecto.Query for root with_ties true with existing limit and order_by" do
      expected =
        "posts"
        |> order_by([], desc: :inserted_at)
        |> limit(^1)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [order_by: [desc: :inserted_at], limit: 1, with_ties: true],
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_ties payload is invalid" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{with_ties: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_ties value to be a boolean or keyword/map payload"
    end
  end

  describe "windows shapes (schemaless)" do
    test "matches Ecto.Query for a root windows partition_by atom" do
      field_name = :author_id

      expected =
        windows("posts", [p], post_window: [partition_by: [field(p, ^field_name)], order_by: []])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{windows: [post_window: [partition_by: :author_id]]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "parent_as equality (schemaless)" do
    test "matches Ecto.Query for a root binding equality" do
      expected = from(c in "comments", where: c.post_id == field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{parent_as: %{post: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated root binding equality" do
      expected = from(c in "comments", where: c.post_id != field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{not: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a greater-than comparison" do
      expected = from(c in "comments", where: c.id > field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{id: %{>: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "first, limit, offset shapes (schemaless)" do
    test "matches Ecto.Query for a root integer first" do
      expected = limit("posts", ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{first: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root integer limit" do
      expected = limit("posts", ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root integer offset" do
      expected = offset("posts", ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{offset: 5},
          []
        )

      assert_query(expected, actual)
    end
  end
end
