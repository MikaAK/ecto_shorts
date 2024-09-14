defmodule EctoShorts.QueryBuilder.Schema.ComparisonFilterTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder.Schema.ComparisonFilter

  alias EctoShorts.QueryBuilder.Schema.ComparisonFilter
  alias EctoShorts.Support.Schemas.{
    Comment,
    Post,
    User
  }

  require Ecto.Query

  describe "build: " do
    test "raises if value is nil" do
      expected_error_message = ~r|comparison with nil is forbidden as it is unsafe|

      func =
        fn ->
          ComparisonFilter.build(Comment, :id, nil)
        end

      assert_raise ArgumentError, expected_error_message, func
    end

    test "returns query where record has value" do
      query = ComparisonFilter.build(Comment, :id, 1)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record has value in list" do
      query = ComparisonFilter.build(Comment, :id, [1])

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{[1], {:in, {0, :id}}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record has value that equals nil" do
      query = ComparisonFilter.build(Comment, :body, %{==: nil})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:is_nil, [], [{{:., [], [{:&, [], [0]}, :body]}, [], []}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value greater than the specified value" do
      query = ComparisonFilter.build(Comment, :id, %{gt: 1})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value less than the specified value" do
      query = ComparisonFilter.build(Comment, :id, %{lt: 1})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value equal to or greater than the specified value" do
      query = ComparisonFilter.build(Comment, :id, %{gte: 1})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>=, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value equal to or less than the specified value" do
      query = ComparisonFilter.build(Comment, :id, %{lte: 1})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<=, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record matches by like comparison" do
      query = ComparisonFilter.build(Comment, :body, %{like: "body"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:like, [], [{{:., [], [{:&, [], [0]}, :body]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"%body%", :string}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record matches by ilike comparison" do
      query = ComparisonFilter.build(Comment, :body, %{ilike: "body"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:ilike, [], [{{:., [], [{:&, [], [0]}, :body]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"%body%", :string}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal nil" do
      query = ComparisonFilter.build(Comment, :body, %{!=: nil})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:is_nil, [], [{{:., [], [{:&, [], [0]}, :body]}, [], []}]}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal value" do
      query = ComparisonFilter.build(Comment, :body, %{!=: "body"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:!=, [], [{{:., [], [{:&, [], [0]}, :body]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"body", {0, :body}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record not in list" do
      query = ComparisonFilter.build(Comment, :id, %{!=: [1]})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]}]},
            op: :and,
            params: [{[1], {:in, {0, :id}}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal lowercase string" do
      query = ComparisonFilter.build(Comment, :body, %{!=: {:lower, "body"}})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :!=,
              [],
              [
                {:fragment, [],
                  [
                    raw: "lower(",
                    expr: {{:., [], [{:&, [], [0]}, :body]}, [], []},
                    raw: ")"
                  ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal uppercase string" do
      query = ComparisonFilter.build(Comment, :body, %{!=: {:upper, "body"}})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :!=,
              [],
              [
                {:fragment, [],
                  [
                    raw: "upper(",
                    expr: {{:., [], [{:&, [], [0]}, :body]}, [], []},
                    raw: ")"
                  ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query by DateTime" do
      query = ComparisonFilter.build(Comment, :inserted_at, ~U[2024-09-07 15:37:20Z])

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %DateTime{
                  calendar: Calendar.ISO,
                  day: 7,
                  hour: 15,
                  microsecond: {0, 0},
                  minute: 37,
                  month: 9,
                  second: 20,
                  std_offset: 0,
                  time_zone: "Etc/UTC",
                  utc_offset: 0,
                  year: 2024,
                  zone_abbr: "UTC"
                },
                {0, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query by NaiveDateTime" do
      query = ComparisonFilter.build(Comment, :inserted_at, ~N[2024-09-07 15:37:20])

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %NaiveDateTime{
                  calendar: Calendar.ISO,
                  day: 7,
                  hour: 15,
                  microsecond: {0, 0},
                  minute: 37,
                  month: 9,
                  second: 20,
                  year: 2024
                },
                {0, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query with fragment for lower" do
      query = ComparisonFilter.build(Comment, :body, {:lower, "body"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :==,
              [],
              [
                {:fragment, [],
                [
                  raw: "lower(",
                  expr: {{:., [], [{:&, [], [0]}, :body]}, [], []},
                  raw: ")"
                ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query with fragment for upper" do
      query = ComparisonFilter.build(Comment, :body, {:upper, "body"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :==,
              [],
              [
                {:fragment, [],
                [
                  raw: "upper(",
                  expr: {{:., [], [{:&, [], [0]}, :body]}, [], []},
                  raw: ")"
                ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end
  end

  describe "build_array: " do
    test "returns query where record has value in list" do
      query = ComparisonFilter.build_array(Comment, :id, [1])

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{[1], {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record has value" do
      query = ComparisonFilter.build_array(Comment, :id, 1)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:in, [], [{:^, [], [0]}, {{:., [], [{:&, [], [0]}, :id]}, [], []}]},
            op: :and,
            params: [{1, {:out, {0, :id}}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record has value that is not nil" do
      query = ComparisonFilter.build_array(Comment, :id, %{!=: nil})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:is_nil, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}]}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end
  end

  describe "build_relational: " do
    test "raises if value is nil" do
      expected_error_message = ~r|comparison with nil is forbidden as it is unsafe|

      func =
        fn ->
          ComparisonFilter.build_relational(Comment, :id, nil)
        end

      assert_raise ArgumentError, expected_error_message, func
    end

    test "raises if filter params is not a map" do
      expected_error_message = ~r|must provide a map for associations to filter on|

      func =
        fn ->
          Comment
          |> Ecto.Query.from(as: :comment)
          |> ComparisonFilter.build_relational(:comment, 1, User)
        end

      assert_raise ArgumentError, expected_error_message, func
    end

    test "returns a query the association is invalid" do
      query = Ecto.Query.from(Comment, as: :comment)

      assert ^query = ComparisonFilter.build_relational(query, :comment, %{invalid_association: %{id: 1}}, User)
    end

    test "returns a query matching a record when params is a map and the field is not an association" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{user_id: 1}, User)

      assert %Ecto.Query{
        aliases: %{comment: 0},
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :user_id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :user_id}}],
          }
        ]
      } = query
    end

    test "returns a query joining a has_many association with the :through option and matching a record with a column value in the list" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{authors: %{id: 1}}, Post)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_authors: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_authors,
            assoc: {0, :authors},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns a query joining an association and matching a record with a column value in the list" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: [1]}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:in, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{[1], {:in, {1, :id}}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query that joins on a relational schema association and matches on record by DateTime" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{inserted_at: ~U[2024-09-05 16:13:21Z]}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %DateTime{
                  calendar: Calendar.ISO,
                  day: 5,
                  hour: 16,
                  microsecond: {0, 0},
                  minute: 13,
                  month: 9,
                  second: 21,
                  std_offset: 0,
                  time_zone: "Etc/UTC",
                  utc_offset: 0,
                  year: 2024,
                  zone_abbr: "UTC"
                },
                {1, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query that joins on a relational schema association and matches on record by NaiveDateTime" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{inserted_at: ~N[2024-09-07 15:37:20]}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %NaiveDateTime{
                  calendar: Calendar.ISO,
                  day: 7,
                  hour: 15,
                  microsecond: {0, 0},
                  minute: 37,
                  month: 9,
                  second: 20,
                  year: 2024
                },
                {1, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns a query that matches on a query field of a relational schema record with comparison filter parameters" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{id: %{!=: nil}}, User)

      assert %Ecto.Query{
        aliases: %{comment: 0},
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:is_nil, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}]}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query that joins on a relational schema association that matches on a query_field of the association" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: "title"}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"title", {1, :title}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns a query that can join on nested associations" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{user: %{id: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1,
          comment_posts_user: 2
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          },
          %Ecto.Query.JoinExpr{
            as: :comment_posts_user,
            assoc: {1, :user},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [2]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {2, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has value that equals nil" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: %{==: nil}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:is_nil, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value greater than the specified value" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{gt: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value less than the specified value" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{lt: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value equal to or greater than the specified value" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{gte: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>=, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record has a value equal to or less than the specified value" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{lte: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<=, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record matches by like comparison" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: %{like: "title"}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:like, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"%title%", :string}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where record matches by ilike comparison" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: %{ilike: "title"}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          as: :comment,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:ilike, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{"%title%", :string}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal nil" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{!=: nil}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:is_nil, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}]}]},
            op: :and,
            params: [],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal value" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{!=: 1}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:!=, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record not in list" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{!=: [1]}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:not, [], [{:in, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]}]},
            op: :and,
            params: [{[1], {:in, {1, :id}}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal lowercase string" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{!=: {:lower, "body"}}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :!=,
              [],
              [
                {:fragment, [],
                  [
                    raw: "lower(",
                    expr: {{:., [], [{:&, [], [1]}, :id]}, [], []},
                    raw: ")"
                  ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query where matching record does not equal uppercase string" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{id: %{!=: {:upper, "body"}}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {
              :!=,
              [],
              [
                {:fragment, [],
                  [
                    raw: "upper(",
                    expr: {{:., [], [{:&, [], [1]}, :id]}, [], []},
                    raw: ")"
                  ]},
                {:^, [], [0]}
              ]
            },
            op: :and,
            params: [{"body", :any}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query by DateTime" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{inserted_at: ~U[2024-09-07 15:37:20Z]}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %DateTime{
                  calendar: Calendar.ISO,
                  day: 7,
                  hour: 15,
                  microsecond: {0, 0},
                  minute: 37,
                  month: 9,
                  second: 20,
                  std_offset: 0,
                  time_zone: "Etc/UTC",
                  utc_offset: 0,
                  year: 2024,
                  zone_abbr: "UTC"
                },
                {1, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query by NaiveDateTime" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{inserted_at: ~N[2024-09-07 15:37:20]}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
          comment_posts: 1
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [
              {
                %NaiveDateTime{
                  calendar: Calendar.ISO,
                  day: 7,
                  hour: 15,
                  microsecond: {0, 0},
                  minute: 37,
                  month: 9,
                  second: 20,
                  year: 2024
                },
                {1, :inserted_at}
              }
            ],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query with fragment for lower" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: {:lower, "title"}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{{:lower, "title"}, {1, :title}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query with fragment for upper" do
      query =
        Comment
        |> Ecto.Query.from(as: :comment)
        |> ComparisonFilter.build_relational(:comment, %{posts: %{title: {:upper, "title"}}}, User)

      assert %Ecto.Query{
        aliases: %{
          comment: 0,
        },
        from: %Ecto.Query.FromExpr{
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :comment_posts,
            assoc: {0, :posts},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :title]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{{:upper, "title"}, {1, :title}}],
            subqueries: []
          }
        ]
      } = query
    end
  end
end
