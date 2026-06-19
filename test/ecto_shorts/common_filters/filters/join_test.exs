defmodule EctoShorts.CommonFilters.JoinTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :join

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Join
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog


  describe "join shapes" do
    test "matches Ecto.Query for an association join payload" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [association: [source: :author, as: :author]]},
          []
        )

      assert_query(expected, actual)
    end

    # Three outer-key forms are supported for association joins: the explicit form
    # `[association: [source: :author, as: :author]]`, the type-selector form
    # `[type: :association, source: :author, ...]`, and this shorthand where the
    # outer key is the association name itself.
    test "matches Ecto.Query for an association shorthand join payload" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [author: [as: :author]]},
          []
        )

      assert_query(expected, actual)
    end

    # `type:` selects the source family (`:association`, `:schema`, `:table`, etc.).
    # `qualifier:` selects the join mode (`:left`, `:right`, `:inner`, etc.).
    # The two keys are independent; `type:` does not set the join mode.
    test "matches Ecto.Query for an explicit association join payload using the type source selector" do
      expected =
        from(p in Post,
          left_join: a in assoc(p, :author),
          as: :author,
          on: true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [type: :association, source: :author, as: :author, qualifier: :left, on: true]},
          []
        )

      assert_sql(expected, actual)
    end

    test "matches Ecto.Query for a schema join payload" do
      expected =
        from(p in Post,
          join: u in EctoShorts.Schema.User,
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              schema: [
                source: EctoShorts.Schema.User,
                as: :user,
                on: %{author_id: 1}
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for an explicit schema join payload using the type source selector" do
      expected =
        from(p in Post,
          join: u in EctoShorts.Schema.User,
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [type: :schema, source: EctoShorts.Schema.User, as: :user, on: %{author_id: 1}]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a table join payload" do
      expected =
        from(p in Post,
          join: u in "users",
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              table: [
                source: "users",
                as: :user,
                on: %{author_id: 1}
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    # `hints:` accepts an atom. The atom is resolved to a SQL hint string by the
    # provider before being forwarded to Ecto.
    test "matches Ecto.Query for a table join payload with configured hints" do
      expected =
        from(p in Post,
          join: u in "users",
          as: :user,
          on: p.author_id == ^1,
          hints: ["USE INDEX(test_index)"]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              table: [
                source: "users",
                as: :user,
                on: %{author_id: 1},
                hints: :test_index
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a query join payload" do
      user_query = from(u in EctoShorts.Schema.User, where: u.age > ^18)

      expected =
        from(p in Post,
          join: u in ^user_query,
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              query: [
                source: user_query,
                as: :user,
                on: %{author_id: 1}
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a subquery join payload built from params" do
      user_query = from(u in EctoShorts.Schema.User, where: u.age > ^18)

      expected =
        from(p in Post,
          join: u in subquery(user_query),
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              subquery: [
                source: [from: EctoShorts.Schema.User, age: {:>, 18}],
                as: :user,
                on: %{author_id: 1}
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding association join payload" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          join: ap in assoc(a, :posts),
          as: :author_posts
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                join: [
                  association: [source: :posts, as: :author_posts]
                ]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # Fragment joins require the `query_provider:` opt. The provider receives the
    # source name and values and must return `{:ok, %Ecto.Query{}}`. The three
    # tests below cover the nil, error, and invalid-return branches.
    test "matches Ecto.Query for a fragment join payload through the provider contract" do
      active_users =
        from(u in fragment("SELECT * FROM users WHERE age >= ?", ^18), select: u)

      expected =
        from(p in Post,
          join: u in ^active_users,
          as: :users,
          on: true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              fragment: [
                source: [name: :active_users, values: %{min_age: 18}],
                as: :users,
                on: true
              ]
            ]
          },
          query_provider: EctoShorts.TestQueryProvider
        )

      assert_query(expected, actual)
    end

    test "legacy :query_provider_module runtime opt is NOT honored — falls through to no-provider path" do
      # When the old _module key is passed, opts[:query_provider] is nil (key not
      # present). The resolver finds no provider and emits a warning, leaving the
      # query unchanged — proving the old key is not picked up.
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  fragment: [
                    source: [name: :active_users, values: %{min_age: 18}],
                    as: :users,
                    on: true
                  ]
                ]
              },
              query_provider_module: EctoShorts.TestQueryProvider
            )

          assert_query(expected, actual)
        end)

      assert log =~ "No query provider module configured for fragment join source"
    end

    # A nil return from the provider leaves the query unchanged.
    test "keeps the query unchanged when the fragment provider returns nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              fragment: [
                source: [
                  name: :active_users,
                  values: %{min_age: 18}
                ],
                as: :users,
                on: true
              ]
            ]
          },
          query_provider: EctoShorts.TestNoOpQueryProvider
        )

      assert_query(expected, actual)
    end

    # An `{:error, reason}` return from the provider logs a warning and leaves the
    # query unchanged.
    test "keeps the query unchanged when the fragment provider returns an error" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  fragment: [
                    source: [
                      name: :error_fragment,
                      values: %{}
                    ],
                    as: :users,
                    on: true
                  ]
                ]
              },
              query_provider: EctoShorts.TestQueryProvider
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Join source callback returned error for key :error_fragment: :forced_error"
    end

    # A return value that is not `{:ok, query}`, `{:error, reason}`, or `nil` is
    # out of contract and raises (D-PROVIDER).
    test "raises when the fragment provider returns a raw source (out of contract)" do
      assert_raise EctoShorts.FilterError, ~r/join source callback must return/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              fragment: [
                source: [name: :legacy_active_users, values: %{min_age: 18}],
                as: :users,
                on: true
              ]
            ]
          },
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end
  end

  describe "join extended paths" do
    test "keeps the query unchanged and logs when join type key is unrecognised" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{join: [bad_key: [source: Post]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected join type to be one of"
    end

    test "keeps the query unchanged and logs when join options has no :source key" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{join: [association: [as: :author]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected join options to have a :source key"
    end

    test "keeps the query unchanged and logs when a join entry is not a map or keyword list" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{join: ["not_a_pair"]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :join params to be a map or keyword list"
    end

    test "raises when fragment join source name is missing" do
      assert_raise ArgumentError, ~r/Join source name is required/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [fragment: [source: [values: %{}], as: :users, on: true]]},
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end

    test "raises when fragment join source values are missing" do
      assert_raise ArgumentError, ~r/Join source values are required/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [fragment: [source: [name: :active_users], as: :users, on: true]]},
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end

    test "raises when schema join target is not a valid atom or {table, schema} tuple" do
      assert_raise ArgumentError, ~r/Expected target schema/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [schema: [source: 123, as: :user]]},
          []
        )
      end
    end

    test "matches Ecto.Query for a schema join using a {table, schema} tuple" do
      expected =
        from(p in Post,
          join: u in {"users", EctoShorts.Schema.User},
          as: :user,
          on: true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              schema: [
                source: {"users", EctoShorts.Schema.User},
                as: :user,
                on: true
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "raises when query join source is not an Ecto.Query struct" do
      assert_raise ArgumentError, ~r/Expected source query to be a struct/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{join: [query: [source: "not_a_query", as: :user]]},
          []
        )
      end
    end

    test "keeps the query unchanged when :on list is not a keyword list" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  association: [source: :author, as: :author, on: [:bad]]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :on to be a keyword list, map, or true"
    end

    test "matches Ecto.Query for a subquery join from a prebuilt Ecto.Query" do
      user_query = from(u in EctoShorts.Schema.User, where: u.age > ^18)

      expected =
        from(p in Post,
          join: u in subquery(user_query),
          as: :user,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              subquery: [
                source: user_query,
                as: :user,
                on: %{author_id: 1}
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "processes a nested non-keyword list of join entries" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          join: c in assoc(p, :comments),
          as: :comments
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              [association: [source: :author, as: :author]],
              [association: [source: :comments, as: :comments]]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "Join.hints/0" do
    test "returns the compiled hints list" do
      assert is_list(Join.hints())
    end
  end

  describe "join :on with keyword list that produces nil dynamic" do
    import ExUnit.CaptureLog

    test "keeps the query unchanged when keyword :on filters all produce nil dynamics" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  association: [
                    source: :author,
                    as: :author,
                    on: [nonexistent_field_xyz: 5]
                  ]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field"
      assert log =~ "does not exist on schema"
    end
  end

  describe "join :on with pre-built DynamicExpr" do
    test "matches Ecto.Query when :on is a pre-built dynamic expression" do
      dynamic_on = dynamic([p], p.id == ^1)

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          on: ^dynamic_on
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              association: [
                source: :author,
                as: :author,
                on: dynamic_on
              ]
            ]
          },
          []
        )

      assert_sql(expected, actual)
    end
  end

  describe "join :on with invalid (non-list, non-map) value" do
    test "keeps the query unchanged and logs when :on is not a valid filter shape" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  association: [source: :author, as: :author, on: 42]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :on to be a keyword list, map, or true"
    end
  end

  describe "join :on with named binding context" do
    test "resolves source from the named binding when building :on dynamics" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                join: [
                  association: [
                    source: :posts,
                    as: :author_posts,
                    on: %{id: 1}
                  ]
                ]
              }
            }
          },
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "join :on with positional binding context" do
    test "resolves source from the positional binding when building :on dynamics" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                join: [
                  association: [
                    source: :posts,
                    on: %{id: 1}
                  ]
                ]
              }
            }
          },
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "join :on merge_dynamic paths" do
    import ExUnit.CaptureLog

    # merge_dynamic(a, _, nil) fires when the second of two on-entries produces nil.
    # A keyword list :on is used to guarantee the order of entries: the valid field
    # is processed first (producing a dynamic), then the nonexistent field (producing
    # nil). This also exercises the keyword list path in reduce_on_params.
    test "keeps first dynamic when the second on-field produces nil" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          on: p.id == ^1
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                join: [
                  association: [
                    source: :author,
                    as: :author,
                    on: [id: 1, nonexistent_field_xyz: 5]
                  ]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field"
      assert log =~ "does not exist on schema"
    end

    # merge_dynamic(a, :and, b) fires when both on-entries produce valid dynamics
    test "merges two valid on-field dynamics with AND" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              association: [
                source: :author,
                as: :author,
                on: %{id: 1, author_id: 2}
              ]
            ]
          },
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "join with association and hints" do
    test "matches Ecto.Query for an association join with configured hints" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          on: true,
          hints: ["USE INDEX(test_index)"]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              association: [
                source: :author,
                as: :author,
                on: true,
                hints: :test_index
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "join with subquery and hints" do
    test "matches Ecto.Query for a subquery join with configured hints" do
      user_query = from(u in EctoShorts.Schema.User, where: u.age > ^18)

      expected =
        from(p in Post,
          join: u in subquery(user_query),
          as: :user,
          on: true,
          hints: ["USE INDEX(test_index)"]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            join: [
              subquery: [
                source: user_query,
                as: :user,
                on: true,
                hints: :test_index
              ]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from join (schemaless) ----
  describe "join shapes (schemaless)" do
    @describetag feature: :join
    @describetag schema_mode: :schemaless
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
end
