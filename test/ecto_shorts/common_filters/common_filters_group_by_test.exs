defmodule EctoShorts.CommonFilters.GroupByTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "convert_params_to_filter/3 group_by shapes" do
    test "matches Ecto.Query for a root group_by atom" do
      expected = from(p in Post, group_by: :author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{group_by: :author_id},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root group_by list" do
      expected = from(p in Post, group_by: [:author_id, :title])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{group_by: [:author_id, :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root group_by dynamic list" do
      dynamic_expr = dynamic([p], fragment("lower(?)", p.title))
      expected = from(p in Post, group_by: ^[:author_id, dynamic_expr])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{group_by: [:author_id, dynamic_expr]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding group_by atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = group_by(source, [author: a], field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                group_by: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding group_by list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = group_by(source, [author: a], [field(a, ^field_name)])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                group_by: [:first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding group_by dynamic list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      field_expr = dynamic([author: a], field(a, ^field_name))
      dynamic_expr = dynamic([author: a], fragment("lower(?)", a.first_name))
      expected = group_by(source, [author: a], ^[field_expr, dynamic_expr])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                group_by: [:first_name, dynamic_expr]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding group_by atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = group_by(source, [_, a], field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                group_by: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding group_by list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = group_by(source, [_, a], [field(a, ^field_name)])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                group_by: [:first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding group_by dynamic list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      field_expr = dynamic([_, a], field(a, ^field_name))
      dynamic_expr = dynamic([_, a], fragment("lower(?)", a.first_name))
      expected = group_by(source, [_, a], ^[field_expr, dynamic_expr])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                group_by: [:first_name, dynamic_expr]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
