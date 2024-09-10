defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonFilters

  alias EctoShorts.CommonFilters
  alias EctoShorts.Support.Schemas.Post

  describe "convert_params_to_filter: " do
    test "returns query with expected defaults" do
      expected_title = "title"

      assert query = CommonFilters.convert_params_to_filter(Post, %{title: expected_title})

      assert %Ecto.Query{
        aliases: %{},
        assocs: [],
        combinations: [],
        distinct: nil,
        from: %Ecto.Query.FromExpr{
          as: nil,
          file: nil,
          hints: [],
          line: nil,
          params: [],
          prefix: nil,
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        group_bys: [],
        havings: [],
        joins: [],
        limit: nil,
        lock: nil,
        offset: nil,
        order_bys: [],
        prefix: nil,
        preloads: [],
        select: nil,
        sources: nil,
        updates: [],
        wheres: [
          %Ecto.Query.BooleanExpr{
            params: [
              {^expected_title, {0, :title}}
            ]
          }
        ],
        windows: [],
        with_ctes: nil
      } = query
    end

    test "returns query with preloads" do
      assert query = CommonFilters.convert_params_to_filter(Post, %{preload: :comments})

      assert %Ecto.Query{preloads: preloads} = query

      assert [:comments] = preloads
    end

    test "returns a query where inserted_at is on or after start_date" do
      expected_start_date = ~U[2024-09-05 16:13:21Z]

      assert query = CommonFilters.convert_params_to_filter(Post, %{start_date: expected_start_date})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:>=, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_start_date, {0, :inserted_at}}
          ]
        }
      ] = wheres
    end

    test "returns a query where inserted_at is on or before end_date" do
      expected_end_date = ~U[2024-09-05 16:13:21Z]

      assert query = CommonFilters.convert_params_to_filter(Post, %{end_date: expected_end_date})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:<=, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_end_date, {0, :inserted_at}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is less than integer value" do
      expected_id = 1

      assert query = CommonFilters.convert_params_to_filter(Post, %{before: expected_id})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:<, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_id, {0, :id}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is greater than integer value" do
      expected_id = 1

      assert query = CommonFilters.convert_params_to_filter(Post, %{after: expected_id})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:>, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_id, {0, :id}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is less than string value" do
      expected_id = "binary_id"

      assert query = CommonFilters.convert_params_to_filter(Post, %{before: expected_id})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:<, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_id, {0, :id}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is greater than string value" do
      expected_id = "binary_id"

      assert query = CommonFilters.convert_params_to_filter(Post, %{after: expected_id})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:>, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_id, {0, :id}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is in a member of a list of integer values" do
      expected_ids = [1, 2]

      assert query = CommonFilters.convert_params_to_filter(Post, %{ids: expected_ids})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_ids, {:in, {0, :id}}}
          ]
        }
      ] = wheres
    end

    test "returns a query where ID is in a member of a list of string values" do
      expected_ids = ["binary_id_1", "binary_id_2"]

      assert query = CommonFilters.convert_params_to_filter(Post, %{ids: expected_ids})

      assert %Ecto.Query{wheres: wheres} = query

      assert [
        %Ecto.Query.BooleanExpr{
          expr: {:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
          params: [
            {^expected_ids, {:in, {0, :id}}}
          ]
        }
      ] = wheres
    end

    test "returns a query with limit when first is specified" do
      expected_first = 5

      assert query = CommonFilters.convert_params_to_filter(Post, %{first: expected_first})

      assert %Ecto.Query{
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [
            {^expected_first, :integer}
          ]
        },
        order_bys: []
      } = query
    end

    test "returns a query with limit by last" do
      expected_last = 5

      assert query = CommonFilters.convert_params_to_filter(Post, %{last: expected_last})

      assert %Ecto.Query{
        from: from,
        limit: nil,
        order_bys: order_bys
      } = query

      assert %Ecto.Query.FromExpr{
        source: %Ecto.SubQuery{
          query: %Ecto.Query{
            limit: %Ecto.Query.LimitExpr{
              expr: {:^, [], [0]},
              params: [
                {^expected_last, :integer}
              ]
            }
          }
        }
      } = from

      # order should be ascending by default
      assert [
        %Ecto.Query.QueryExpr{
          expr: [asc: {{:., [], [{:&, [], [0]}, :id]}, [], []}],
          params: []
        }
      ] = order_bys
    end

    test "returns a query with limit when limit is specified" do
      expected_limit = 5

      assert query = CommonFilters.convert_params_to_filter(Post, %{limit: expected_limit})

      assert %Ecto.Query{
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [
            {^expected_limit, :integer}
          ]
        },
        order_bys: []
      } = query
    end

    test "returns a query with offset when offset is specified" do
      expected_offset = 5

      assert query = CommonFilters.convert_params_to_filter(Post, %{offset: expected_offset})

      assert %Ecto.Query{
        offset: %Ecto.Query.QueryExpr{
          params: [{^expected_offset, :integer}]
        }
      } = query
    end

    test "returns a query with items in ascending order" do
      assert query = CommonFilters.convert_params_to_filter(Post, %{order_by: {:asc, :id}})

      assert %Ecto.Query{
        order_bys: [
          %Ecto.Query.QueryExpr{
            expr: [asc: {{:., [], [{:&, [], [0]}, :id]}, [], []}],
            params: []
          }
        ]
      } = query
    end

    test "returns a query with items in descending order" do
      assert query = CommonFilters.convert_params_to_filter(Post, %{order_by: {:desc, :id}})

      assert %Ecto.Query{
        order_bys: [
          %Ecto.Query.QueryExpr{
            expr: [desc: {{:., [], [{:&, [], [0]}, :id]}, [], []}],
            params: []
          }
        ]
      } = query
    end

    test "returns a query that is built from the search parameter" do
      expected_id = 1

      assert query = CommonFilters.convert_params_to_filter(Post, %{search: %{id: expected_id}})

      assert %Ecto.Query{
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
  end
end
