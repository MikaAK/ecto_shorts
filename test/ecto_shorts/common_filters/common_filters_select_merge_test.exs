defmodule EctoShorts.CommonFilters.SelectMergeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "convert_params_to_filter/3 select_merge shapes" do
    test "matches Ecto.Query for a root select_merge keyword alias mapping" do
      source = from(p in Post, select: %{})

      expected =
        from(p in Post,
          select: %{},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select_merge map alias mapping" do
      source = from(p in Post, select: %{})

      expected =
        from(p in Post,
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

    test "matches Ecto.Query for a root select_merge map tuple alias mapping" do
      source = from(p in Post, select: %{})

      expected =
        from(p in Post,
          select: %{},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: {:map, %{post_title: :title}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding select_merge alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{}
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          select: %{},
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                select_merge: %{author_name: :first_name}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding select_merge alias mapping" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          select: %{}
        )

      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          select: %{},
          select_merge: %{author_name: a.first_name}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                select_merge: %{author_name: :first_name}
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when select_merge merges onto an existing select" do
      source = from(p in Post, select: %{post_id: p.id})

      expected =
        from(p in Post,
          select: %{post_id: p.id},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: %{post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
