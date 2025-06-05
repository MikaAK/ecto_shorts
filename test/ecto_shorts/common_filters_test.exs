defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonFilters

  alias EctoShorts.{
    CommonFilters,
    Schemas.PostAbstract,
    Schemas.Post,
    Schemas.User
  }

  import Ecto.Query, only: [from: 2]
  import EctoShorts.Testing, only: [assert_query: 2]

  describe "&convert_params_to_filter/3" do
    test "no operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.published == ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: true})
    end

    test "no operator, db field is scalar, value is list" do
      query = from p in Post, where: p.title in ^["example"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{title: ["example"]})
    end

    # ---

    test "no operator, db field is array, value is scalar" do
      query = from p in Post, where: ^"example" in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: "example"})
    end

    test "no operator, db field is array, value is list" do
      query = from p in Post, where: p.tags == ^["example"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: ["example"]})
    end

    # ---

    test ":eq operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.published == ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: %{eq: true}})
    end

    # ---

    test ":eq operator, db field is array, value is scalar" do
      query = from p in Post, where: ^"example" in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{eq: "example"}})
    end

    test ":eq operator, db field is array, value is list" do
      query = from p in Post, where: p.tags == ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{eq: ["example"]}})
    end

    # ---

    test ":not operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.published != ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: %{not: true}})
    end

    # ---

    test ":not operator, db field is array, value is scalar" do
      query = from p in Post, where: ^"example" not in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{not: "example"}})
    end

    test ":not operator, db field is array, value is list" do
      query = from p in Post, where: p.tags != ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{not: ["example"]}})
    end

    # ---

    test ":ilike operator, db field is scalar, value is scalar" do
      query = from p in Post, where: ilike(p.title, ^"%example%")

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "example"}})
    end

    test ":ilike operator, db field is scalar, value is list" do
      query =
        from p in Post, where: fragment("? ILIKE ANY(SELECT unnest(?))", p.title, ^["%example%"])

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: ["example"]}})
    end

    # ---

    test ":ilike operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? ILIKE ANY(?)", ^"%example%", p.tags)

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{ilike: "example"}})
    end

    test ":ilike operator, db field is array, value is list" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{ilike: ["example"]}})
    end

    # ---

    test ":like operator, db field is scalar, value is scalar" do
      query = from p in Post, where: like(p.title, ^"%example%")

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{like: "example"}})
    end

    test ":like operator, db field is scalar, value is list" do
      query =
        from p in Post, where: fragment("? LIKE ANY(SELECT unnest(?))", p.title, ^["%example%"])

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{like: ["example"]}})
    end

    # ---

    test ":like operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? LIKE ANY(?)", ^"%example%", p.tags)

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{like: "example"}})
    end

    test ":like operator, db field is array, value is list" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{like: ["example"]}})
    end

    # ---

    test ":=~ operator, db field is scalar, value is scalar" do
      query = from p in Post, where: fragment("? ~* ?", p.title, ^"example")
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{title: %{=~: "example"}})
    end

    test ":=~ operator, db field is scalar, value is list" do
      query =
        from p in Post,
          where: fragment("? ~* ?", p.title, ^"A") or fragment("? ~* ?", p.title, ^"B")

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{=~: ["A", "B"]}})
    end

    # ---

    test ":=~ operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? ~* ANY(?)", ^"example", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{=~: "example"}})
    end

    test ":=~ operator, db field is array, value is list" do
      query =
        from p in Post,
          where:
            fragment(
              "EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ~* ?)",
              p.tags,
              ^["example"]
            )

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{=~: ["example"]}})
    end

    # ---

    test ":== operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.published == ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: %{==: true}})
    end

    test ":== operator, db field is scalar, value is list" do
      query = from p in Post, where: p.title in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{==: ["example"]}})
    end

    # ---

    test ":== operator, db field is array, value is scalar" do
      query = from p in Post, where: ^"example" in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{==: "example"}})
    end

    test ":== operator, db field is array, value is list" do
      query = from p in Post, where: p.tags == ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{==: ["example"]}})
    end

    # ---

    test "creates query, compares if value is not in array, db field is scalar type, :!= is operator, and scalar value" do
      query = from p in Post, where: p.published != ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: %{!=: true}})
    end

    test "creates query, compares if value is not in array, db field is array type, :!= is operator, and scalar value" do
      query = from p in Post, where: ^"example" not in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: "example"}})
    end

    test "creates query, compares if arrays do not match, db field is array type, :!= is operator, and list value" do
      query = from p in Post, where: p.tags != ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: ["example"]}})
    end

    # ---

    test "creates query with less than comparison, db field is scalar type, :< is operator, and scalar value" do
      query = from p in Post, where: p.views < ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<: 1}})
    end

    test "creates query with less than comparison, db field is array type, :< is operator, and scalar value" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :< is operator, and list value" do
      query = from p in Post, where: p.tags < ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<: ["B"]}})
    end

    # ---

    test "creates query with less than comparison, db field is scalar type, :lt is operator, and scalar value" do
      query = from p in Post, where: p.views < ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{lt: 1}})
    end

    test "creates query with less than comparison, db field is array type, :lt is operator, and scalar value" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lt: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :lt is operator, and scalar value" do
      query = from p in Post, where: p.tags < ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lt: ["B"]}})
    end

    # ---

    test "creates query with less than comparison, db field is scalar type, :<= is operator, and scalar value" do
      query = from p in Post, where: p.views <= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<=: 1}})
    end

    test "creates query with less than comparison, db field is array type, :<= is operator, and scalar value" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<=: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :<= is operator, and list value" do
      query = from p in Post, where: p.tags <= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<=: ["B"]}})
    end

    # ---

    test "creates query with less than comparison, db field is scalar type, :lte is operator, and scalar value" do
      query = from p in Post, where: p.views <= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{lte: 1}})
    end

    test "creates query with less than comparison, db field is array type, :lte is operator, and scalar value" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lte: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :lte is operator, and list value" do
      query = from p in Post, where: p.tags <= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lte: ["B"]}})
    end

    # ---

    test "creates query with greater than comparison, db field is scalar type, :> is operator, and scalar value" do
      query = from p in Post, where: p.views > ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>: 1}})
    end

    test "creates query with greater than comparison, db field is array type, :> is operator, and scalar value" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :> is operator, and list value" do
      query = from p in Post, where: p.tags > ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>: ["B"]}})
    end

    # ---

    test "creates query with greater than comparison, db field is scalar type, :gt is operator, and scalar value" do
      query = from p in Post, where: p.views > ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{gt: 1}})
    end

    test "creates query with greater than comparison, db field is array type, :gt is operator, and scalar value" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gt: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :gt is operator, and scalar value" do
      query = from p in Post, where: p.tags > ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gt: ["B"]}})
    end

    # ---

    test "creates query with greater than comparison, db field is scalar type, :>= is operator, and scalar value" do
      query = from p in Post, where: p.views >= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>=: 1}})
    end

    test "creates query with greater than comparison, db field is array type, :>= is operator, and scalar value" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>=: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :>= is operator, and list value" do
      query = from p in Post, where: p.tags >= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>=: ["B"]}})
    end

    # ---

    test "creates query with greater than comparison, db field is scalar type, :gte is operator, and scalar value" do
      query = from p in Post, where: p.views >= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{gte: 1}})
    end

    test "creates query with greater than comparison, db field is array type, :gte is operator, and scalar value" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gte: "B"}})
    end

    test "creates query, compares arrays, db field is array type, :gte is operator, and list value" do
      query = from p in Post, where: p.tags >= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gte: ["B"]}})
    end

    # ---

    test "creates query with upper string comparison, db field is scalar type, :== is operator with :lower, and scalar value" do
      query = from p in Post, where: fragment("LOWER(?)", p.title) == ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{lower: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :== is operator with :lower, and scalar value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{==: %{lower: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :== is operator with :lower, and list value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{==: %{lower: ["example"]}}
                   })
    end

    # ---

    test "creates query with upper string comparison, db field is scalar type, :== is operator with :upper, and scalar value" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) == ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{upper: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :== is operator with :upper, and scalar value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{==: %{upper: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :== is operator with :upper, and list value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{==: %{upper: ["example"]}}
                   })
    end

    # ---

    test "creates query with upper string comparison, db field is scalar type, :!= is operator with :lower, and scalar value" do
      query =
        from p in Post,
          where: fragment("LOWER(?)", p.title) != ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{lower: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :!= is operator with :lower, and scalar value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{!=: %{lower: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :!= is operator with :lower, and list value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{!=: %{lower: ["example"]}}
                   })
    end

    # ---

    test "creates query with upper string comparison, db field is scalar type, :!= is operator with :upper, and scalar value" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) != ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{upper: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :!= is operator with :upper, and scalar value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{!=: %{upper: "example"}}
                   })
    end

    test "creates query with upper string comparison, db field is array type, :!= is operator with :upper, and list value" do
      query =
        from p in Post,
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

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     tags: %{!=: %{upper: ["example"]}}
                   })
    end

    # ---

    # test "creates query with upper string comparison, db field is array type, :!= is operator with :lower, and value is an array of string" do
    #   query =
    #     from p in Post,
    #       where:
    #         fragment(
    #           """
    #           (
    #             SELECT array_agg(LOWER(db_tag))
    #             FROM unnest(?::text[]) AS db_tag
    #           )
    #           <>
    #           (
    #             SELECT array_agg(LOWER(input_tag))
    #             FROM unnest(?::text[]) AS input_tag
    #           )
    #           """,
    #           field(p, :tags),
    #           ^["example"]
    #         )

    #   assert_query query,
    #                CommonFilters.convert_params_to_filter(Post, %{
    #                  tags: %{!=: %{lower: ["example"]}}
    #                })
    # end

    # test "creates query with upper string comparison, db field is array type, :!= is operator with :upper, and value is an array of string" do
    #   query =
    #     from p in Post,
    #       where:
    #         fragment(
    #           """
    #           (
    #             SELECT array_agg(UPPER(db_tag))
    #             FROM unnest(?::text[]) AS db_tag
    #           )
    #           <>
    #           (
    #             SELECT array_agg(UPPER(input_tag))
    #             FROM unnest(?::text[]) AS input_tag
    #           )
    #           """,
    #           field(p, :tags),
    #           ^["example"]
    #         )

    #   assert_query query,
    #                CommonFilters.convert_params_to_filter(Post, %{
    #                  tags: %{!=: %{upper: ["example"]}}
    #                })
    # end

    # ***

    # test "field on schema has an query source tuple {source, schema}" do
    #   expected_query =
    #     from p in {"posts", PostAbstract},
    #       join: c in assoc(p, :comments),
    #       as: :ecto_shorts_comments,
    #       where: c.id == ^1

    #   actual_query =
    #     CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{comments: %{id: 1}})

    #   assert_query actual_query, expected_query
    # end

    # test "1" do
    #   expected_query =
    #     from p in {"posts", PostAbstract},
    #       join: a in assoc(p, :author),
    #       as: :ecto_shorts_author,
    #       where: a.age == ^0

    #   actual_query =
    #     CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{author: %{age: 0}})

    #   assert_query actual_query, expected_query
    # end

    # test "2" do
    #   expected_query =
    #     from p in {"posts", PostAbstract},
    #       join: a in assoc(p, :authors),
    #       as: :ecto_shorts_authors,
    #       where: a.age == ^0

    #   actual_query =
    #     CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{authors: %{age: 0}})

    #   assert_query actual_query, expected_query
    # end

    # test "3" do
    #   expected_query =
    #     from p in {"posts", PostAbstract},
    #       join: a in assoc(p, :comments),
    #       as: :ecto_shorts_comments,
    #       where: a.id == ^1

    #   actual_query =
    #     CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{comments: %{id: 1}})

    #   assert_query actual_query, expected_query
    # end

    # test "belongs_to relationship" do
    #   expected_query =
    #     from p in Post, join: a in assoc(p, :author), as: :ecto_shorts_author, where: a.id == ^1

    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{author: %{id: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "many_to_many relationship" do
    #   expected_query =
    #     from p in Post, join: a in assoc(p, :authors), as: :ecto_shorts_authors, where: a.id == ^1

    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{authors: %{id: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "has_many relationship" do
    #   expected_query =
    #     from p in Post,
    #       join: a in assoc(p, :comments),
    #       as: :ecto_shorts_comments,
    #       where: a.id == ^1

    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{comments: %{id: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "nested association" do
    #   query =
    #     from u in User,
    #       join: c in assoc(u, :comments),
    #       as: :ecto_shorts_comments,
    #       join: p in assoc(c, :post),
    #       as: :ecto_shorts_post,
    #       where: p.title == ^"example"

    #   assert_query query,
    #                CommonFilters.convert_params_to_filter(User, %{
    #                  comments: %{post: %{title: "example"}}
    #                })
    # end

    # test "raises when given a non-direct association has_through" do
    #   expected_message =
    #     """
    #     Expected a direct association with a `:related` key, but got
    #     an association that does not support direct Ecto operations.

    #     This likely happens when using a `:through` association,
    #     which cannot be used with functions like `put_assoc` or
    #     `cast_assoc`.

    #     Supported associations include: `belongs_to`, `has_one`,, `has_many`.

    #     key:

    #     :comments_authors

    #     association:

    #     %Ecto.Association.HasThrough{
    #       cardinality: :many,
    #       field: :comments_authors,
    #       owner: EctoShorts.Schemas.PostAbstract,
    #       owner_key: :id,
    #       through: [:comments, :author],
    #       on_cast: nil,
    #       relationship: :child,
    #       unique: true,
    #       ordered: false
    #     }

    #     schema:

    #     EctoShorts.Schemas.PostAbstract
    #     """

    #   assert_raise ArgumentError, expected_message, fn ->
    #     CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{
    #       comments_authors: %{id: 1}
    #     })
    #   end
    # end

    # #
    # # Base cases
    # #

    # test "returns the base query when params are empty" do
    #   expected_query = Post
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{})
    #   assert_query actual_query, expected_query
    # end

    # #
    # # Equality tests
    # #

    # # integer

    # test "builds a query with == on integer field using direct value" do
    #   expected_query = from p in Post, where: p.id == ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: 1})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with == on integer field using explicit :== operator" do
    #   expected_query = from p in Post, where: p.id == ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{==: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with != on integer field" do
    #   expected_query = from p in Post, where: p.id != ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{!=: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with > on integer field" do
    #   expected_query = from p in Post, where: p.id > ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{>: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with < on integer field" do
    #   expected_query = from p in Post, where: p.id < ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{<: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with >= on integer field" do
    #   expected_query = from p in Post, where: p.id >= ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{>=: 1}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with <= on integer field" do
    #   expected_query = from p in Post, where: p.id <= ^1
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{<=: 1}})
    #   assert_query actual_query, expected_query
    # end

    # #
    # # String matching
    # #

    # test "builds a query with like on string field" do
    #   expected_query = from p in Post, where: like(p.title, ^"%example%")

    #   actual_query =
    #     CommonFilters.convert_params_to_filter(Post, %{title: %{like: "example"}})

    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with ilike on string field" do
    #   expected_query = from p in Post, where: ilike(p.title, ^"%example%")

    #   actual_query =
    #     CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "example"}})

    #   assert_query actual_query, expected_query
    # end

    # #
    # # Array field
    # #

    # test "builds a query where string is checked as 'in' against array field" do
    #   expected_query = from p in Post, where: ^"example" in p.tags
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{tags: "example"})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query where list matches exactly against array field" do
    #   expected_query = from p in Post, where: p.tags == ^["example"]
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{tags: ["example"]})
    #   assert_query actual_query, expected_query
    # end

    # #
    # # Association join
    # #

    # test "builds a query that joins association, filters nested value" do
    #   expected_query =
    #     from p in Post,
    #       join: c in assoc(p, :comments),
    #       as: :ecto_shorts_comments,
    #       where: c.id == ^1

    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{comments: %{id: 1}})
    #   assert_query actual_query, expected_query
    # end

    # #
    # # Query Shaping
    # #

    # test "builds a query with preload" do
    #   expected_query = from p in Post, preload: [:comments]
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{preload: [:comments]})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with select using map syntax" do
    #   expected_query = from p in Post, select: map(p, [:id])
    #   actual_query = CommonFilters.convert_params_to_filter(Post, %{select: %{map: [:id]}})
    #   assert_query actual_query, expected_query
    # end

    # test "builds a query with select_merge on an existing select" do
    #   expected_query = from p in Post, select: map(p, [:id, :title])

    #   base_query = from p in Post, select: map(p, [:id])

    #   actual_query =
    #     CommonFilters.convert_params_to_filter(base_query, %{select_merge: [:title]})

    #   assert_query actual_query, expected_query
    # end
  end
end
