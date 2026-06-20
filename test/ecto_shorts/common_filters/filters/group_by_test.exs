defmodule EctoShorts.CommonFilters.GroupByTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :group_by

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query


  import ExUnit.CaptureLog

  describe "group_by shapes" do
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

  describe "group_by edge cases" do
    test "skips invalid schema field atom, returns query unchanged" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{group_by: [:nonexistent_field]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "nonexistent_field"
    end

    # Covers reduce_params/4 fallback (line 40): when group_by value is not an atom or list
    # (e.g. a DynamicExpr), the fallback clause applies ^expr directly.
    test "accepts a bare DynamicExpr as a group_by value" do
      dyn = dynamic([p], p.author_id)
      expected = from(p in Post, group_by: ^dyn)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{group_by: dyn},
          []
        )

      assert_query(expected, actual)
    end

    # Covers reduce_params_exprs/4 catch-all (line 55): non-atom, non-DynamicExpr entries
    # are passed through as-is. Ecto raises at query-build time, but coverage is recorded first.
    test "raises when group_by list contains non-atom non-DynamicExpr entries" do
      assert_raise ArgumentError, fn ->
        CommonFilters.convert_params_to_filter(Post, %{group_by: ["author_id"]}, [])
      end
    end
  end

  # ---- merged from group_by (schemaless) ----
  describe "group_by shapes (schemaless)" do
    @describetag feature: :group_by
    @describetag schema_mode: :schemaless
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

  describe "group_by invalid scalar guard" do

    test "returns query unchanged and warns when group_by is a non-atom scalar" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{group_by: 5}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end
end
