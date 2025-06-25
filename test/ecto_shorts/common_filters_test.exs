defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonFilters

  alias EctoShorts.{
    CommonFilters,
    Schemas.Post,
    Schemas.PostAbstract,
    Schemas.PostHasQueryBuilder,
    Schemas.PostHasTupleFieldSource,
    TestQueryBuilder
  }

  import Ecto.Query, only: [from: 2, subquery: 1]
  import EctoShorts.Testing, only: [assert_query: 2]

  describe "&convert_params_to_filter/3" do
    test "returns the base query when params are empty" do
      expected_query = Post
      actual_query = CommonFilters.convert_params_to_filter(Post, %{})
      assert_query actual_query, expected_query
    end

    test "can pass custom adapter using :query_builder_adapter option" do
      expected_query = from Post, limit: ^5

      actual_query =
        CommonFilters.convert_params_to_filter(Post, %{limit: 5},
          query_builder_adapter: TestQueryBuilder
        )

      assert_query actual_query, expected_query
    end

    test "can build using the custom query builder in the schema module (it calls the build_query/5 callback function)" do
      expected_query = from p in PostHasQueryBuilder, where: p.published == ^true

      actual_query =
        CommonFilters.convert_params_to_filter(PostHasQueryBuilder, %{custom_schema_filter: true})

      assert_query actual_query, expected_query
    end

    # ---

    test ":last filter" do
      expected_query =
        from p in subquery(
               from p in Post,
                 where: p.published == ^true,
                 order_by: [desc: p.inserted_at],
                 limit: ^5
             ),
             order_by: [asc: p.id]

      actual_query = CommonFilters.convert_params_to_filter(Post, %{published: true, last: 5})
      assert_query actual_query, expected_query
    end

    # ---

    test ":preload filter" do
      expected_query = from p in Post, preload: [:comments]
      actual_query = CommonFilters.convert_params_to_filter(Post, %{preload: [:comments]})
      assert_query actual_query, expected_query
    end

    # ---

    test ":select filter, returns map of fields" do
      expected_query = from p in Post, select: map(p, [:id])
      actual_query = CommonFilters.convert_params_to_filter(Post, %{select: %{map: [:id]}})
      assert_query actual_query, expected_query
    end

    test ":select filter, returns struct of fields" do
      expected_query = from p in Post, select: struct(p, [:id])
      actual_query = CommonFilters.convert_params_to_filter(Post, %{select: %{struct: [:id]}})
      assert_query actual_query, expected_query
    end

    # ---

    test ":select_merge filter, can select merge on map given list" do
      expected_query = from p in Post, select: map(p, [:id, :title])
      base_query = from p in Post, select: map(p, [:id])
      actual_query = CommonFilters.convert_params_to_filter(base_query, %{select_merge: [:title]})
      assert_query actual_query, expected_query
    end

    test ":select_merge filter, can select merge on struct given list" do
      expected_query = from p in Post, select: struct(p, [:id, :title])
      base_query = from p in Post, select: struct(p, [:id])
      actual_query = CommonFilters.convert_params_to_filter(base_query, %{select_merge: [:title]})
      assert_query actual_query, expected_query
    end

    # ---

    test ":select_merge filter, can select merge on map given params" do
      expected_query = from p in Post, select: map(p, [:id, :title])
      base_query = from p in Post, select: map(p, [:id])

      actual_query =
        CommonFilters.convert_params_to_filter(base_query, %{select_merge: %{map: [:title]}})

      assert_query actual_query, expected_query
    end

    test ":select_merge filter, can select merge on struct given params" do
      expected_query = from p in Post, select: struct(p, [:id, :title])
      base_query = from p in Post, select: struct(p, [:id])

      actual_query =
        CommonFilters.convert_params_to_filter(base_query, %{select_merge: %{struct: [:title]}})

      assert_query actual_query, expected_query
    end

    # ---

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

    test ":lt operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views < ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{lt: 1}})
    end

    test ":lt operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? < ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{lt: [1, 2, 3]}})
    end

    # ---

    test ":lt operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lt: "B"}})
    end

    test ":lt operator, db field is array, value is list" do
      query = from p in Post, where: p.tags < ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lt: ["B"]}})
    end

    # ---

    test ":lte operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views <= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{lte: 1}})
    end

    test ":lte operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? <= ANY(?)", p.views, ^[1, 2, 3])

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{views: %{lte: [1, 2, 3]}})
    end

    # ---

    test ":lte operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lte: "B"}})
    end

    test ":lte operator, db field is array, value is list" do
      query = from p in Post, where: p.tags <= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{lte: ["B"]}})
    end

    # ---

    test ":gt operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views > ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{gt: 1}})
    end

    test ":gt operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? > ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{gt: [1, 2, 3]}})
    end

    # ---

    test ":gt operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gt: "B"}})
    end

    test ":gt operator, db field is array, value is list" do
      query = from p in Post, where: p.tags > ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gt: ["B"]}})
    end

    # ---

    test ":gte operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views >= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{gte: 1}})
    end

    test ":gte operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? >= ANY(?)", p.views, ^[1, 2, 3])

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{views: %{gte: [1, 2, 3]}})
    end

    # ---

    test ":gte operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gte: "B"}})
    end

    test ":gte operator, db field is array, value is list" do
      query = from p in Post, where: p.tags >= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{gte: ["B"]}})
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

    test ":!= operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.published != ^true
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{published: %{!=: true}})
    end

    test ":!= operator, db field is scalar, value is list" do
      query = from p in Post, where: p.title not in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{title: %{!=: ["example"]}})
    end

    # ---

    test ":!= operator, db field is array, value is scalar" do
      query = from p in Post, where: ^"example" not in p.tags
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: "example"}})
    end

    test ":!= operator, db field is array, value is a list" do
      query = from p in Post, where: p.tags != ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: ["example"]}})
    end

    # ---

    test ":< operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views < ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<: 1}})
    end

    test ":< operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? < ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<: [1, 2, 3]}})
    end

    # ---

    test ":< operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<: "B"}})
    end

    test ":< operator, db field is array, value is list" do
      query = from p in Post, where: p.tags < ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<: ["B"]}})
    end

    # ---

    test ":<= operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views <= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<=: 1}})
    end

    test ":<= operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? <= ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{<=: [1, 2, 3]}})
    end

    # ---

    test ":<= operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<=: "B"}})
    end

    test ":<= operator, db field is array, value is list" do
      query = from p in Post, where: p.tags <= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{<=: ["B"]}})
    end

    # ---

    test ":> operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views > ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>: 1}})
    end

    test ":> operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? > ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>: [1, 2, 3]}})
    end

    # ---

    test ":> operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>: "B"}})
    end

    test ":> operator, db field is array, value is list" do
      query = from p in Post, where: p.tags > ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>: ["B"]}})
    end

    # ---

    test ":>= operator, db field is scalar, value is scalar" do
      query = from p in Post, where: p.views >= ^1
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>=: 1}})
    end

    test ":>= operator, db field is scalar, value is list" do
      query = from p in Post, where: fragment("? >= ANY(?)", p.views, ^[1, 2, 3])
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{views: %{>=: [1, 2, 3]}})
    end

    # ---

    test ":>= operator, db field is array, value is scalar" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"B", p.tags)
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>=: "B"}})
    end

    test ":>= operator, db field is array, value is list" do
      query = from p in Post, where: p.tags >= ^["B"]
      assert_query query, CommonFilters.convert_params_to_filter(Post, %{tags: %{>=: ["B"]}})
    end

    # ---

    test ":== operator, :lower function, db field is scalar, value is scalar" do
      query = from p in Post, where: fragment("LOWER(?)", p.title) == ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{lower: "example"}}
                   })
    end

    test ":== operator, :lower function, db field is scalar, value is list" do
      query = from p in Post, where: fragment("LOWER(?)", p.title) in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{lower: ["example"]}}
                   })
    end

    # ---

    test ":== operator, :lower function, db field is array, value is scalar" do
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

    test ":== operator, :lower function, db field is array, value is list" do
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

    test ":== operator, :upper function, db field is scalar, value is scalar" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) == ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{upper: "example"}}
                   })
    end

    test ":== operator, :upper function, db field is scalar, value is list" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{==: %{upper: ["example"]}}
                   })
    end

    # ---

    test ":== operator, :upper function, db field is array, value is scalar" do
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

    test ":== operator, :upper function, db field is array, value is list" do
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

    test ":!= operator, :lower function, db field is scalar, value is scalar" do
      query =
        from p in Post,
          where: fragment("LOWER(?)", p.title) != ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{lower: "example"}}
                   })
    end

    test ":!= operator, :lower function, db field is scalar, value is list" do
      query =
        from p in Post,
          where: fragment("LOWER(?)", p.title) not in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{lower: ["example"]}}
                   })
    end

    # ---

    test ":!= operator, :lower function, db field is array, value is scalar" do
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

    test ":!= operator, :lower function, db field is array, value is list" do
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

    test ":!= operator, :upper function, db field is scalar, value is scalar" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) != ^"example"

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{upper: "example"}}
                   })
    end

    test ":!= operator, :upper function, db field is scalar, value is list" do
      query =
        from p in Post,
          where: fragment("UPPER(?)", p.title) not in ^["example"]

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     title: %{!=: %{upper: ["example"]}}
                   })
    end

    # ---

    test ":!= operator, :upper function, db field is array, value is scalar" do
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

    test ":!= operator, :upper function, db field is array, value is list" do
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

    test "builds query given {source, schema} tuple" do
      expected_query = from p in {"posts", PostAbstract}, where: p.published == ^true

      actual_query =
        CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{published: true})

      assert_query actual_query, expected_query
    end

    test "builds query given field on schema with a source tuple {source, schema}" do
      expected_query =
        from p in PostHasTupleFieldSource,
          join: c in assoc(p, :comments),
          as: :ecto_shorts_comments,
          where: c.id == ^1

      actual_query =
        CommonFilters.convert_params_to_filter(PostHasTupleFieldSource, %{comments: %{id: 1}})

      assert_query actual_query, expected_query
    end

    test "belongs_to relationship" do
      expected_query =
        from p in Post, join: a in assoc(p, :author), as: :ecto_shorts_author, where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{author: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "many_to_many relationship" do
      expected_query =
        from p in Post, join: a in assoc(p, :authors), as: :ecto_shorts_authors, where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{authors: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "has_many relationship" do
      expected_query =
        from p in Post,
          join: a in assoc(p, :comments),
          as: :ecto_shorts_comments,
          where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{comments: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "creates query with non-unique nested associations" do
      query =
        from p in Post,
          join: a in assoc(p, :author),
          as: :ecto_shorts_author,
          join: c in assoc(p, :comments),
          as: :ecto_shorts_comments,
          join: cp in assoc(c, :post),
          as: :ecto_shorts_comments_post,
          join: cpa in assoc(cp, :author),
          as: :ecto_shorts_comments_post_author,
          where: a.id == ^123,
          where: cpa.id == ^456

      assert_query query,
                   CommonFilters.convert_params_to_filter(Post, %{
                     author: %{id: 123},
                     comments: %{post: %{author: %{id: 456}}}
                   })
    end
  end
end
