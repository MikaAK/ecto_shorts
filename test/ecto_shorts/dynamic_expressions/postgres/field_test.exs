defmodule EctoShorts.DynamicExpressions.Postgres.FieldTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.DynamicExpressions.Postgres.Field

  alias EctoShorts.DynamicExpressions.Postgres.Field
  alias EctoShorts.Schemas.Post

  import Ecto.Query, only: [dynamic: 2, from: 2]
  import EctoShorts.Testing, only: [assert_dynamic: 2, assert_query: 2]

  describe "create_dynamic" do
    test "without binding alias, :ilike operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], ilike(d.title, ^"%example%")),
                     Field.build_dynamic(nil, :title, :ilike, "example")
    end

    test "with binding alias, :ilike operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: ilike(p.title, ^"%example%")

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :ilike, "example")

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :ilike operator, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment("? ILIKE ANY(SELECT unnest(?))", d.title, ^["%example%"])
                     ),
                     Field.build_dynamic(nil, :title, :ilike, ["example"])
    end

    test "with binding alias, :ilike operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? ILIKE ANY(SELECT unnest(?))", p.title, ^["%example%"])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :ilike, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :like operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], like(d.title, ^"%example%")),
                     Field.build_dynamic(nil, :title, :like, "example")
    end

    test "with binding alias, :like operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: like(p.title, ^"%example%")

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :like, "example")

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :like operator, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment("? LIKE ANY(SELECT unnest(?))", d.title, ^["%example%"])
                     ),
                     Field.build_dynamic(nil, :title, :like, ["example"])
    end

    test "with binding alias, :like operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? LIKE ANY(SELECT unnest(?))", p.title, ^["%example%"])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :like, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :=~ operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], fragment("? ~* ?", d.title, ^"example")),
                     Field.build_dynamic(nil, :title, :=~, "example")
    end

    test "with binding alias, :=~ operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? ~* ?", p.title, ^"example")

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :=~, "example")

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :=~ operator, key on left, list on right" do
      assert_dynamic dynamic(
                       [d],
                       fragment("? ~* ?", d.title, ^"A") or fragment("? ~* ?", d.title, ^"B")
                     ),
                     Field.build_dynamic(nil, :title, :=~, ["A", "B"])
    end

    test "with binding alias, :=~ operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? ~* ?", p.title, ^"A") or fragment("? ~* ?", p.title, ^"B")

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :=~, ["A", "B"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, key on left, nil on right" do
      assert_dynamic dynamic([d], is_nil(d.title)),
                     Field.build_dynamic(nil, :title, :==, nil)
    end

    test "with binding alias, :== operator, key on left, nil on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: is_nil(p.title)

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :==, nil)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.title == ^"example"),
                     Field.build_dynamic(nil, :title, :==, "example")
    end

    test "with binding alias, :== operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.title == ^"example"

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :==, "example")

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.title in ^["example"]),
                     Field.build_dynamic(nil, :title, :==, ["example"])
    end

    test "with binding alias, :== operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.title in ^["example"]

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :==, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :lower function, key on left, scalar on right" do
      assert_dynamic dynamic([d], fragment("LOWER(?)", d.title) == ^"example"),
                     Field.build_dynamic(nil, :title, :==, {:lower, "example"})
    end

    test "with binding alias, :== operator, :lower function, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("LOWER(?)", p.title) == ^"example"

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :==, {:lower, "example"})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :lower function, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("LOWER(?)", d.title) in ^["example"]),
                     Field.build_dynamic(nil, :title, :==, {:lower, ["example"]})
    end

    test "with binding alias, :== operator, :lower function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("LOWER(?)", p.title) in ^["example"]

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :==, {:lower, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :upper function, key on left, scalar on right" do
      assert_dynamic dynamic([d], fragment("UPPER(?)", d.title) == ^"example"),
                     Field.build_dynamic(nil, :title, :==, {:upper, "example"})
    end

    test "with binding alias, :== operator, :upper function, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("UPPER(?)", p.title) == ^"example"

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :==, {:upper, "example"})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :== operator, :upper function, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("UPPER(?)", d.title) in ^["example"]),
                     Field.build_dynamic(nil, :title, :==, {:upper, ["example"]})
    end

    test "with binding alias, :== operator, :upper function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("UPPER(?)", p.title) in ^["example"]

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :==, {:upper, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, key on left, nil on right" do
      assert_dynamic dynamic([d], not is_nil(d.title)),
                     Field.build_dynamic(nil, :title, :!=, nil)
    end

    test "with binding alias, :!= operator, key on left, nil on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: not is_nil(p.title)

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :!=, nil)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.title != ^"example"),
                     Field.build_dynamic(nil, :title, :!=, "example")
    end

    test "with binding alias, :!= operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.title != ^"example"

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :!=, "example")

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, key on left, list on right" do
      assert_dynamic dynamic([d], d.title not in ^["example"]),
                     Field.build_dynamic(nil, :title, :!=, ["example"])
    end

    test "with binding alias, :!= operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.title not in ^["example"]

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :title, :!=, ["example"])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :lower function, key on left, scalar on right" do
      assert_dynamic dynamic([d], fragment("LOWER(?)", d.title) != ^"example"),
                     Field.build_dynamic(nil, :title, :!=, {:lower, "example"})
    end

    test "with binding alias, :!= operator, :lower function, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("LOWER(?)", p.title) != ^"example"

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :!=, {:lower, "example"})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :lower function, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("LOWER(?)", d.title) not in ^["example"]),
                     Field.build_dynamic(nil, :title, :!=, {:lower, ["example"]})
    end

    test "with binding alias, :!= operator, :lower function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("LOWER(?)", p.title) not in ^["example"]

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :!=, {:lower, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :upper function, key on left, scalar on right" do
      assert_dynamic dynamic([d], fragment("UPPER(?)", d.title) != ^"example"),
                     Field.build_dynamic(nil, :title, :!=, {:upper, "example"})
    end

    test "with binding alias, :!= operator, :upper function, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("UPPER(?)", p.title) != ^"example"

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :!=, {:upper, "example"})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :!= operator, :upper function, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("UPPER(?)", d.title) not in ^["example"]),
                     Field.build_dynamic(nil, :title, :!=, {:upper, ["example"]})
    end

    test "with binding alias, :!= operator, :upper function, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("UPPER(?)", p.title) not in ^["example"]

      actual_query =
        from p in Post,
          as: :post,
          where: ^Field.build_dynamic(:post, :title, :!=, {:upper, ["example"]})

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :< operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.views < ^1),
                     Field.build_dynamic(nil, :views, :<, 1)
    end

    test "with binding alias, :< operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.views < ^1

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :<, 1)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :< operator, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("? < ANY(?)", d.views, ^[1, 2, 3])),
                     Field.build_dynamic(nil, :views, :<, [1, 2, 3])
    end

    test "with binding alias, :< operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? < ANY(?)", p.views, ^[1, 2, 3])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :<, [1, 2, 3])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :> operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.views > ^1),
                     Field.build_dynamic(nil, :views, :>, 1)
    end

    test "with binding alias, :> operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.views > ^1

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :>, 1)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :> operator, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("? > ANY(?)", d.views, ^[1, 2, 3])),
                     Field.build_dynamic(nil, :views, :>, [1, 2, 3])
    end

    test "with binding alias, :> operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? > ANY(?)", p.views, ^[1, 2, 3])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :>, [1, 2, 3])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :<= operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.views <= ^1),
                     Field.build_dynamic(nil, :views, :<=, 1)
    end

    test "with binding alias, :<= operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.views <= ^1

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :<=, 1)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :<= operator, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("? <= ANY(?)", d.views, ^[1, 2, 3])),
                     Field.build_dynamic(nil, :views, :<=, [1, 2, 3])
    end

    test "with binding alias, :<= operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? <= ANY(?)", p.views, ^[1, 2, 3])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :<=, [1, 2, 3])

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :>= operator, key on left, scalar on right" do
      assert_dynamic dynamic([d], d.views >= ^1),
                     Field.build_dynamic(nil, :views, :>=, 1)
    end

    test "with binding alias, :>= operator, key on left, scalar on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: p.views >= ^1

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :>=, 1)

      assert_query expected_query, actual_query
    end

    # ---

    test "without binding alias, :>= operator, key on left, list on right" do
      assert_dynamic dynamic([d], fragment("? >= ANY(?)", d.views, ^[1, 2, 3])),
                     Field.build_dynamic(nil, :views, :>=, [1, 2, 3])
    end

    test "with binding alias, :>= operator, key on left, list on right" do
      expected_query =
        from p in Post,
          as: :post,
          where: fragment("? >= ANY(?)", p.views, ^[1, 2, 3])

      actual_query =
        from p in Post, as: :post, where: ^Field.build_dynamic(:post, :views, :>=, [1, 2, 3])

      assert_query expected_query, actual_query
    end
  end
end
