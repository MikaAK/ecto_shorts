defmodule EctoShorts.CommonFilters.HavingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :having

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "having shapes" do
    import ExUnit.CaptureLog

    test "returns query unchanged when having is nil" do
      expected = from(p in Post, group_by: p.author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          expected,
          %{having: nil},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when or_having is nil" do
      expected = from(p in Post, group_by: p.author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          expected,
          %{or_having: nil},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root aggregate having" do
      source = from(p in Post, group_by: p.author_id)
      expected = from(p in Post, group_by: p.author_id, having: avg(p.views) > ^100)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{avg: %{>: 100}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root negated having" do
      source = from(p in Post, group_by: [p.title, p.views])
      expected = from(p in Post, group_by: [p.title, p.views], having: not (p.views > ^10))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{not: %{>: 10}}}},
          []
        )

      assert_query(expected, actual)
    end

    # `having:` accepts a pre-built `Ecto.Query.DynamicExpr` directly in addition to
    # the nested map syntax.
    test "matches Ecto.Query for a root dynamic having" do
      source = from(p in Post, group_by: p.author_id)
      dynamic_expr = dynamic([p], avg(p.views) > 10)
      expected = from(p in Post, group_by: p.author_id, having: ^dynamic_expr)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: dynamic_expr},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root dynamic or_having" do
      source = from(p in Post, group_by: p.author_id)
      dynamic_expr = dynamic([p], avg(p.views) > 10)
      expected = from(p in Post, group_by: p.author_id, or_having: ^dynamic_expr)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{or_having: dynamic_expr},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when or_having resolves to nil dynamic" do
      source = from(p in Post, group_by: p.author_id)
      expected = from(p in Post, group_by: p.author_id)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              source,
              %{or_having: %{nonexistent_field_xyz: 5}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field"
      assert log =~ "does not exist on schema"
    end

    test "matches Ecto.Query for a root or_having" do
      source = from(p in Post, group_by: [p.title, p.views])
      expected = from(p in Post, group_by: [p.title, p.views], or_having: p.views < ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{or_having: %{views: %{<: 5}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding aggregate having" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          group_by: a.first_name
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          group_by: a.first_name,
          having: avg(a.age) > ^10
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                having: %{age: %{avg: %{>: 10}}}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding or_having" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          group_by: [a.first_name, a.age]
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          group_by: [a.first_name, a.age],
          or_having: a.age < ^5
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                or_having: %{age: %{<: 5}}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding aggregate having" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          group_by: a.first_name
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          group_by: a.first_name,
          having: avg(a.age) > ^10
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                having: %{age: %{avg: %{>: 10}}}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding or_having" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          group_by: [a.first_name, a.age]
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          group_by: [a.first_name, a.age],
          or_having: a.age < ^5
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                or_having: %{age: %{<: 5}}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
