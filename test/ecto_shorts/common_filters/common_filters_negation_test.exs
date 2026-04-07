defmodule EctoShorts.CommonFilters.NegationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "negation" do
    test "excludes records where the field is in the given list" do
      expected = from(p in Post, where: is_nil(p.published) or p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records when == with a list is wrapped in not" do
      expected = from(p in Post, where: is_nil(p.published) or p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{==: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "includes records when != with a list is wrapped in not" do
      expected = from(p in Post, where: not is_nil(p.published) and p.published in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published: %{not: %{!=: [true, false]}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records where the field is greater than the value" do
      expected = from(p in Post, where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{>: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field is greater than or equal to the value" do
      expected = from(p in Post, where: not (p.views >= ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{>=: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field is less than the value" do
      expected = from(p in Post, where: not (p.views < ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{<: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field is less than or equal to the value" do
      expected = from(p in Post, where: not (p.views <= ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{<=: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records where the field equals the value" do
      expected = from(p in Post, where: p.views != ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{==: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated quantified equality" do
      expected =
        from(p in Post,
          where:
            not (p.id ==
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{all: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated quantified any equality" do
      expected =
        from(p in Post,
          where:
            not (p.id ==
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{any: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "includes records where the field equals the value using double negation" do
      expected = from(p in Post, where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{!=: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "includes records where the field equals the value using negated ne alias" do
      expected = from(p in Post, where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{ne: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated gt alias" do
      expected = from(p in Post, where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{gt: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated gte alias" do
      expected = from(p in Post, where: not (p.views >= ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{gte: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated lt alias" do
      expected = from(p in Post, where: not (p.views < ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{lt: 10}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using negated lte alias" do
      expected = from(p in Post, where: not (p.views <= ^10))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{lte: 10}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "negated string transforms" do
    test "includes records where the lowercased field matches the value using not !=" do
      expected = from(p in Post, where: fragment("lower(?)", p.title) == ^"hello")

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{!=: %{lower: "hello"}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "includes records where the uppercased field matches the value using not !=" do
      expected = from(p in Post, where: fragment("upper(?)", p.title) == ^"HELLO")

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{title: %{not: %{!=: %{upper: "HELLO"}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "negated nil checks" do
    test "excludes nil using not ==" do
      expected = from(p in Post, where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{not: %{==: nil}}}, [])

      assert_sql(expected, q2)
    end

    test "includes nil using not !=" do
      expected = from(p in Post, where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{not: %{!=: nil}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "negated quantified comparisons" do
    test "excludes records using negated != all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id !=
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{!=: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated != any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id !=
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{!=: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated > all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id >
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{>: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated > any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id >
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{>: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated >= all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id >=
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{>=: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated >= any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id >=
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{>=: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated < all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id <
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{<: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated < any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id <
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{<: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated <= all comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id <=
                   all(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{<=: %{all: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated <= any comparison" do
      expected =
        from(p in Post,
          where:
            not (p.id <=
                   any(
                     from(c in Comment,
                       where: c.published == ^true,
                       select: c.id
                     )
                   ))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{not: %{<=: %{any: %{from: Comment, where: %{published: true}}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "negated aggregate nil checks" do
    test "excludes nil aggregate using not ==" do
      expected = from(p in Post, where: not is_nil(avg(p.views)))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{==: nil}}}}, [])

      assert_sql(expected, actual)
    end

    test "includes nil aggregate using not !=" do
      expected = from(p in Post, where: is_nil(avg(p.views)))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{!=: nil}}}}, [])

      assert_sql(expected, actual)
    end

    test "aggregate == nil produces is_nil check" do
      expected = from(p in Post, where: is_nil(sum(p.views)))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{==: nil}}}, [])

      assert_sql(expected, actual)
    end

    test "aggregate != nil produces not is_nil check" do
      expected = from(p in Post, where: not is_nil(sum(p.views)))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{!=: nil}}}, [])

      assert_sql(expected, actual)
    end

    test "negated aggregate <= produces not <= check" do
      expected = from(p in Post, where: not (avg(p.views) <= ^10))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{<=: 10}}}}, [])

      assert_sql(expected, actual)
    end

    test "negated aggregate != produces == check" do
      expected = from(p in Post, where: avg(p.views) == ^50)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{!=: 50}}}}, [])

      assert_sql(expected, actual)
    end
  end
end
