defmodule EctoShorts.CommonFilters.DistinctTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "distinct shapes" do
    test "matches Ecto.Query for a root boolean distinct" do
      expected = from(p in Post, distinct: true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root distinct atom" do
      expected = from(p in Post, distinct: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root distinct ordered keyword list" do
      expected = from(p in Post, distinct: [desc: :title])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: [desc: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding distinct atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = distinct(source, [author: a], field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                distinct: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding distinct ordered keyword list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = distinct(source, [author: a], desc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                distinct: [desc: :first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding distinct atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = distinct(source, [_, a], field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                distinct: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding distinct ordered keyword list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = distinct(source, [_, a], desc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                distinct: [desc: :first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "distinct extended shapes" do
    test "matches Ecto.Query for a root distinct bare-atom list" do
      expected = from(p in Post, distinct: [asc: p.title, asc: p.views])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: [:title, :views]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding distinct bare-atom list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = distinct(source, [author: a], asc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{distinct: [:first_name]}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root boolean false distinct" do
      expected = from(p in Post, distinct: false)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: false},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string boolean distinct payload" do
      expected = from(p in Post, distinct: true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: "true"},
          []
        )

      assert_query(expected, actual)
    end

    test "skips ordered-tuple entry for non-existent schema field, returns query unchanged" do
      import ExUnit.CaptureLog
      # :nonexistent_field not on Post → skip entry → exprs=[] while entries≠[] → query unchanged
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{distinct: [{:asc, :nonexistent_field}]},
              []
            )

          assert inspect(actual) == inspect(expected)
        end)

      assert log =~ "nonexistent_field"
    end

    test "skips plain-atom entry for non-existent schema field, returns query unchanged" do
      import ExUnit.CaptureLog
      # All entries invalid → exprs=[] while entries≠[] → query unchanged (no distinct)
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{distinct: [:nonexistent_field]},
              []
            )

          assert inspect(actual) == inspect(expected)
        end)

      assert log =~ "nonexistent_field"
    end

    test "accepts a DynamicExpr in a distinct list" do
      dyn = dynamic([p], p.id)
      expected = from(p in Post, distinct: ^[dyn])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{distinct: [dyn]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
