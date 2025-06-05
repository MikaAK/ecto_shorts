defmodule EctoShorts.DynamicExpressions.Postgres.ArrayTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.DynamicExpressions.Postgres.Array

  alias EctoShorts.DynamicExpressions.Postgres.Array
  alias EctoShorts.Schemas.Post

  import Ecto.Query, only: [dynamic: 2, from: 2]
  import EctoShorts.Testing, only: [assert_dynamic: 2, assert_query: 2]

  describe "create_dynamic" do
    test "without binding alias, :ilike operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? ILIKE ANY(?)", ^"%example%", d.tags)),
                     Array.build_dynamic(nil, "example", :ilike, :tags)
    end

    test "with binding alias, :ilike operator, scalar on left, key on right" do
      expected_query =
        from p in Post, as: :post, where: fragment("? ILIKE ANY(?)", ^"%example%", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :ilike, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :ilike operator, scalar on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         NOT EXISTS (
                           SELECT 1
                           FROM unnest(?) AS input_tag
                           WHERE NOT EXISTS (
                             SELECT 1
                             FROM unnest(?) AS db_tag
                             WHERE input_tag ILIKE db_tag
                           )
                         )
                         """,
                         ^["%example%"],
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :ilike, ["example"])
    end

    test "with binding alias, :ilike operator, scalar on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              NOT EXISTS (
                SELECT 1
                FROM unnest(?) AS input_tag
                WHERE NOT EXISTS (
                  SELECT 1
                  FROM unnest(?) AS db_tag
                  WHERE input_tag ILIKE db_tag
                )
              )
              """,
              ^["%example%"],
              p.tags
            )

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :ilike, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :like operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? LIKE ANY(?)", ^"%example%", d.tags)),
                     Array.build_dynamic(nil, "example", :like, :tags)
    end

    test "with binding alias, :like operator, scalar on left, key on right" do
      expected_query =
        from p in Post, as: :post, where: fragment("? LIKE ANY(?)", ^"%example%", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :like, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :like operator, scalar on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         NOT EXISTS (
                           SELECT 1
                           FROM unnest(?) AS input_tag
                           WHERE NOT EXISTS (
                             SELECT 1
                             FROM unnest(?) AS db_tag
                             WHERE input_tag LIKE db_tag
                           )
                         )
                         """,
                         ^["%example%"],
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :like, ["example"])
    end

    test "with binding alias, :like operator, scalar on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              NOT EXISTS (
                SELECT 1
                FROM unnest(?) AS input_tag
                WHERE NOT EXISTS (
                  SELECT 1
                  FROM unnest(?) AS db_tag
                  WHERE input_tag LIKE db_tag
                )
              )
              """,
              ^["%example%"],
              p.tags
            )

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :like, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :=~ operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? ~* ANY(?)", ^"example", d.tags)),
                     Array.build_dynamic(nil, "example", :=~, :tags)
    end

    test "with binding alias, :=~ operator, scalar on left, key on right" do
      expected_query =
        from p in Post, as: :post, where: fragment("? ~* ANY(?)", ^"example", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :=~, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :=~ operator, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         "EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ~* ?)",
                         d.tags,
                         ^["example"]
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :=~, ["example"])
    end

    test "with binding alias, :=~ operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              "EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ~* ?)",
              p.tags,
              ^["example"]
            )

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :=~, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, key on left, nil on right" do
      assert_dynamic dynamic([d], is_nil(d.tags)), Array.build_dynamic(nil, :tags, :==, nil)
    end

    test "with binding alias, :== operator, key on left, nil on right" do
      expected_query = from p in Post, as: :post, where: is_nil(p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :==, nil)

      assert_query expected_query, actual_query
    end

    # --

    test "without binding alias, :== operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], ^"example" in d.tags),
                     Array.build_dynamic(nil, "example", :==, :tags)
    end

    test "with binding alias, :== operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: ^"example" in p.tags

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :==, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.tags == ^["example"]),
                     Array.build_dynamic(nil, :tags, :==, ["example"])
    end

    test "with binding alias, :== operator, key on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags == ^["example"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :==, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :lower function, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         (
                           SELECT array_agg(LOWER(db_tag))
                           FROM unnest(?::text[]) AS db_tag
                         )
                         =
                         (
                           SELECT array_agg(LOWER(input_tag))
                           FROM unnest(?::text[]) AS input_tag
                         )
                         """,
                         field(d, ^:tags),
                         ^["example"]
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :==, {:lower, ["example"]})
    end

    test "with binding alias, :== operator, :lower function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              (
                SELECT array_agg(LOWER(db_tag))
                FROM unnest(?::text[]) AS db_tag
              )
              =
              (
                SELECT array_agg(LOWER(input_tag))
                FROM unnest(?::text[]) AS input_tag
              )
              """,
              p.tags,
              ^["example"]
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, :tags, :==, {:lower, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :upper function, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         (
                           SELECT array_agg(UPPER(db_tag))
                           FROM unnest(?::text[]) AS db_tag
                         )
                         =
                         (
                           SELECT array_agg(UPPER(input_tag))
                           FROM unnest(?::text[]) AS input_tag
                         )
                         """,
                         field(d, ^:tags),
                         ^["example"]
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :==, {:upper, ["example"]})
    end

    test "with binding alias, :== operator, :upper function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              (
                SELECT array_agg(UPPER(db_tag))
                FROM unnest(?::text[]) AS db_tag
              )
              =
              (
                SELECT array_agg(UPPER(input_tag))
                FROM unnest(?::text[]) AS input_tag
              )
              """,
              p.tags,
              ^["example"]
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, :tags, :==, {:upper, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, key on left, nil on right" do
      assert_dynamic dynamic([d], not is_nil(d.tags)), Array.build_dynamic(nil, :tags, :!=, nil)
    end

    test "with binding alias, :!= operator, key on left, nil on right" do
      expected_query = from p in Post, as: :post, where: not is_nil(p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :!=, nil)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], ^"example" not in d.tags),
                     Array.build_dynamic(nil, "example", :!=, :tags)
    end

    test "with binding alias, :!= operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: ^"example" not in p.tags

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :!=, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.tags != ^["example"]),
                     Array.build_dynamic(nil, :tags, :!=, ["example"])
    end

    test "with binding alias, :!= operator, key on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags != ^["example"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :!=, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :lower function, scalar on left, key on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         NOT (
                           ? = ANY (
                             SELECT LOWER(element)
                             FROM unnest(?::text[]) AS element
                           )
                         )
                         """,
                         ^"example",
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, {:lower, "example"}, :!=, :tags)
    end

    test "with binding alias, :!= operator, :lower function, scalar on left, key on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              NOT (
                ? = ANY (
                  SELECT LOWER(element)
                  FROM unnest(?::text[]) AS element
                )
              )
              """,
              ^"example",
              p.tags
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, {:lower, "example"}, :!=, :tags)

      assert_query expected_query, actual_query
    end

    test "without binding alias, :!= operator, :lower function, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         (
                           SELECT array_agg(LOWER(db_tag))
                           FROM unnest(?::text[]) AS db_tag
                         )
                         <>
                         (
                           SELECT array_agg(LOWER(input_tag))
                           FROM unnest(?::text[]) AS input_tag
                         )
                         """,
                         field(d, ^:tags),
                         ^["example"]
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :!=, {:lower, ["example"]})
    end

    test "with binding alias, :!= operator, :lower function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              (
                SELECT array_agg(LOWER(db_tag))
                FROM unnest(?::text[]) AS db_tag
              )
              <>
              (
                SELECT array_agg(LOWER(input_tag))
                FROM unnest(?::text[]) AS input_tag
              )
              """,
              p.tags,
              ^["example"]
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, :tags, :!=, {:lower, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :upper function, scalar on left, key on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         NOT (
                           ? = ANY (
                             SELECT UPPER(element)
                             FROM unnest(?::text[]) AS element
                           )
                         )
                         """,
                         ^"example",
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, {:upper, "example"}, :!=, :tags)
    end

    test "with binding alias, :!= operator, :upper function, scalar on left, key on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              NOT (
                ? = ANY (
                  SELECT UPPER(element)
                  FROM unnest(?::text[]) AS element
                )
              )
              """,
              ^"example",
              p.tags
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, {:upper, "example"}, :!=, :tags)

      assert_query expected_query, actual_query
    end

    test "without binding alias, :!= operator, :upper function, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         (
                           SELECT array_agg(UPPER(db_tag))
                           FROM unnest(?::text[]) AS db_tag
                         )
                         <>
                         (
                           SELECT array_agg(UPPER(input_tag))
                           FROM unnest(?::text[]) AS input_tag
                         )
                         """,
                         field(d, ^:tags),
                         ^["example"]
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :!=, {:upper, ["example"]})
    end

    test "with binding alias, :!= operator, :upper function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              (
                SELECT array_agg(UPPER(db_tag))
                FROM unnest(?::text[]) AS db_tag
              )
              <>
              (
                SELECT array_agg(UPPER(input_tag))
                FROM unnest(?::text[]) AS input_tag
              )
              """,
              p.tags,
              ^["example"]
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, :tags, :!=, {:upper, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :< operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? < ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :<, :tags)
    end

    test "with binding alias, :< operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? < ANY(?)", ^"A", p.tags)
      actual_query = from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :<, :tags)
      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :< operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.tags < ^["A"]),
                     Array.build_dynamic(nil, :tags, :<, ["A"])
    end

    test "with binding alias, :< operator, key on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags < ^["A"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :<, ["A"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :> operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? > ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :>, :tags)
    end

    test "with binding alias, :> operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? > ANY(?)", ^"A", p.tags)
      actual_query = from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :>, :tags)
      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :> operator, scalar on left, list on right" do
      assert_dynamic dynamic([d], d.tags > ^["A"]),
                     Array.build_dynamic(nil, :tags, :>, ["A"])
    end

    test "with binding alias, :> operator, scalar on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags > ^["A"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :>, ["A"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :<= operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? <= ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :<=, :tags)
    end

    test "with binding alias, :<= operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? <= ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :<=, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :<= operator, scalar on left, list on right" do
      assert_dynamic dynamic([d], d.tags <= ^["A"]),
                     Array.build_dynamic(nil, :tags, :<=, ["A"])
    end

    test "with binding alias, :<= operator, scalar on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags <= ^["A"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :<=, ["A"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :>= operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? >= ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :>=, :tags)
    end

    test "with binding alias, :>= operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? >= ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :>=, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :>= operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.tags >= ^["A"]),
                     Array.build_dynamic(nil, :tags, :>=, ["A"])
    end

    test "with binding alias, :>= operator, scalar on left, list on right" do
      expected_query = from p in Post, as: :post, where: p.tags >= ^["A"]

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, :tags, :>=, ["A"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :eq operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], ^"example" in d.tags),
                     Array.build_dynamic(nil, "example", :eq, :tags)
    end

    test "with binding alias, :eq operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: ^"example" in p.tags

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :eq, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :not operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], ^"example" not in d.tags),
                     Array.build_dynamic(nil, "example", :not, :tags)
    end

    test "with binding alias, :not operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: ^"example" not in p.tags

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "example", :not, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :lt operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? < ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :lt, :tags)
    end

    test "with binding alias, :lt operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? < ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :lt, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :lte operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? <= ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :lte, :tags)
    end

    test "with binding alias, :lte operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? <= ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :lte, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :gt operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? > ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :gt, :tags)
    end

    test "with binding alias, :gt operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? > ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :gt, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :gte operator, scalar on left, key on right" do
      assert_dynamic dynamic([d], fragment("? >= ANY(?)", ^"A", d.tags)),
                     Array.build_dynamic(nil, "A", :gte, :tags)
    end

    test "with binding alias, :gte operator, scalar on left, key on right" do
      expected_query = from p in Post, as: :post, where: fragment("? >= ANY(?)", ^"A", p.tags)

      actual_query =
        from p in Post, as: :post, where: ^Array.build_dynamic(:post, "A", :gte, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :lower function, scalar on left, key on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         ? = ANY (
                             SELECT LOWER(element)
                             FROM unnest(?::text[]) AS element
                           )
                         """,
                         ^"example",
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, {:lower, "example"}, :==, :tags)
    end

    test "with binding alias, :== operator, :lower function, scalar on left, key on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              ? = ANY (
                  SELECT LOWER(element)
                  FROM unnest(?::text[]) AS element
                )
              """,
              ^"example",
              p.tags
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, {:lower, "example"}, :==, :tags)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :upper function, scalar on left, key on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         """
                         ? = ANY (
                             SELECT UPPER(element)
                             FROM unnest(?::text[]) AS element
                           )
                         """,
                         ^"example",
                         d.tags
                       )
                     ),
                     Array.build_dynamic(nil, {:upper, "example"}, :==, :tags)
    end

    test "with binding alias, :== operator, :upper function, scalar on left, key on right" do
      expected_query =
        from p in Post,
          as: :post,
          where:
            fragment(
              """
              ? = ANY (
                  SELECT UPPER(element)
                  FROM unnest(?::text[]) AS element
                )
              """,
              ^"example",
              p.tags
            )

      actual_query =
        from p in Post,
          as: :post,
          where: ^Array.build_dynamic(:post, {:upper, "example"}, :==, :tags)

      assert_query expected_query, actual_query
    end
  end
end
