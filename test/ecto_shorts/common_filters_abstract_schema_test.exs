defmodule EctoShorts.CommonFiltersAbstractSchemaTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonFilters

  alias EctoShorts.CommonFilters
  alias EctoShorts.Support.Schemas.FileInfo

  describe "convert_params_to_filter: " do
    test "returns query with expected defaults" do
      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        prefix: nil,
        wheres: [
          %Ecto.Query.BooleanExpr{
            params: [
              {"example.txt", {0, :name}}
            ]
          }
        ]
      } = query
    end

    test "returns query with preloads" do
      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{preload: :comments})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        preloads: [:comments]
      } = query
    end

    test "returns a query where inserted_at is on or after start_date" do
      expected_start_date = ~U[2024-09-05 16:13:21Z]

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{start_date: expected_start_date})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>=, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_start_date, {0, :inserted_at}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where inserted_at is on or before end_date" do
      expected_end_date = ~U[2024-09-05 16:13:21Z]

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{end_date: expected_end_date})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<=, [], [{{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_end_date, {0, :inserted_at}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is less than integer value" do
      expected_id = 1

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{before: expected_id})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_id, {0, :id}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is greater than integer value" do
      expected_id = 1

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{after: expected_id})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_id, {0, :id}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is less than string value" do
      expected_id = "binary_id"

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{before: expected_id})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:<, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_id, {0, :id}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is greater than string value" do
      expected_id = "binary_id"

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{after: expected_id})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:>, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_id, {0, :id}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is in a member of a list of integer values" do
      expected_ids = [1, 2]

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{ids: expected_ids})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_ids, {:in, {0, :id}}}
            ]
          }
        ]
      } = query
    end

    test "returns a query where ID is in a member of a list of string values" do
      expected_ids = ["binary_id_1", "binary_id_2"]

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{ids: expected_ids})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:in, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [
              {^expected_ids, {:in, {0, :id}}}
            ]
          }
        ]
      } = query
    end

    test "returns a query with limit when first is specified" do
      expected_first = 5

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{first: expected_first})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
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

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{last: expected_last})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
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
        },
        limit: nil,
        order_bys: [
          %Ecto.Query.QueryExpr{
            expr: [asc: {{:., [], [{:&, [], [0]}, :id]}, [], []}],
            params: []
          }
        ]
      } = query
    end

    test "returns a query with limit when limit is specified" do
      expected_limit = 5

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{limit: expected_limit})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
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

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{offset: expected_offset})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        offset: %Ecto.Query.QueryExpr{
          params: [{^expected_offset, :integer}]
        }
      } = query
    end

    test "returns a query with items in ascending order" do
      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{order_by: {:asc, :id}})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        order_bys: [
          %Ecto.Query.QueryExpr{
            expr: [asc: {{:., [], [{:&, [], [0]}, :id]}, [], []}],
            params: []
          }
        ]
      } = query
    end

    test "returns a query with items in descending order" do
      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{order_by: {:desc, :id}})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
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

      assert query = CommonFilters.convert_params_to_filter({"file_info_user_avatars", FileInfo}, %{search: %{id: expected_id}})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
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
  end
end
