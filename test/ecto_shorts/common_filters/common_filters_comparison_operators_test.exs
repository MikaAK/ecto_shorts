defmodule EctoShorts.CommonFilters.ComparisonOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "comparison operators" do
    test "matches records where the field equals the value using ==" do
      expected = from(p in Post, where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter(Post, %{id: %{==: 1}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is nil using == nil" do
      expected = from(p in Post, where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{==: nil}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is not nil using != nil" do
      expected = from(p in Post, where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{!=: nil}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is greater than the value" do
      expected = from(p in Post, where: p.views > ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{>: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is greater than or equal to the value" do
      expected = from(p in Post, where: p.views >= ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{>=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is less than the value" do
      expected = from(p in Post, where: p.views < ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{<: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is less than or equal to the value" do
      expected = from(p in Post, where: p.views <= ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{<=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field does not equal the value using !=" do
      expected = from(p in Post, where: p.views != ^10)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: 10}}, [])

      assert_sql(expected, q2)
    end

    test "matches records where the field is in the given list" do
      expected = from(p in Post, where: p.published in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{in: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "treats a list value with == as an IN check" do
      expected = from(p in Post, where: p.published in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{==: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "treats a list value with != as a NOT IN check" do
      expected = from(p in Post, where: p.published not in ^[true, false])
      q2 = CommonFilters.convert_params_to_filter(Post, %{published: %{!=: [true, false]}}, [])

      assert_sql(expected, q2)
    end

    test "preserves struct values like DateTime in the comparison" do
      dt = ~U[2026-01-01 00:00:00Z]
      expected = from(p in Post, where: p.published_at >= ^dt)
      q2 = CommonFilters.convert_params_to_filter(Post, %{published_at: %{>=: dt}}, [])

      assert_sql(expected, q2)
    end

    test "matches records using quantified default equality shorthand" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{all: %{from: Comment, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified any default equality shorthand" do
      expected =
        from(p in Post,
          where:
            p.id ==
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{any: %{from: Comment, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified select override" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.post_id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{all: %{from: Comment, select: %{field: "post_id"}, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified any select override" do
      expected =
        from(p in Post,
          where:
            p.id ==
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.post_id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{any: %{from: Comment, select: %{field: "post_id"}, where: %{published: true}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "falls back to the default quantified select field when a string override is invalid" do
      expected =
        from(p in Post,
          where:
            p.id ==
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                id: %{
                  all: %{
                    from: Comment,
                    select: %{field: "does_not_exist"},
                    where: %{published: true}
                  }
                }
              },
              []
            )

          assert_sql(expected, actual)
        end)

      assert log =~
               "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Comment, skipping field reference"
    end

    test "matches records using quantified greater-than all comparison" do
      expected =
        from(p in Post,
          where:
            p.id >
              all(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{>: %{all: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using quantified greater-than any comparison" do
      expected =
        from(p in Post,
          where:
            p.id >
              any(
                from(c in Comment,
                  where: c.published == ^true,
                  select: c.id
                )
              )
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: %{>: %{any: %{from: Comment, where: %{published: true}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "matches records using the explicit value wrapper for arithmetic expressions" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "raises for an unsupported nil operator" do
      assert_raise ArgumentError, fn ->
        CommonFilters.convert_params_to_filter(Post, %{published_at: %{>: nil}}, [])
      end
    end
  end

  describe "arithmetic negation" do
    test "excludes records using negated arithmetic comparison" do
      expected = from(p in Post, where: not (p.views == p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "value wrapper negation" do
    test "excludes records using negated value-wrapped comparison" do
      expected = from(p in Post, where: p.views != ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: 10}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using negated value-wrapped greater-than" do
      expected = from(p in Post, where: not (p.views > ^5))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>: %{value: 5}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "generic scalar fallback" do
    test "matches records using the generic scalar != fallback" do
      expected = from(p in Post, where: p.views != ^5)
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: %{value: 5}}}, [])

      assert_sql(expected, q2)
    end

    test "excludes records using the negated generic scalar >= fallback" do
      expected = from(p in Post, where: not (p.views >= ^5))
      q2 = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{>=: %{value: 5}}}}, [])

      assert_sql(expected, q2)
    end
  end

  describe "generic datetime comparisons" do
    test "matches records using a datetime ago comparison with date casting" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.published_at) == fragment("date(?)", ago(^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{==: %{date: %{ago: [count: 1, interval: "month"]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "excludes records using a negated datetime ago comparison with date casting" do
      expected =
        from(p in Post,
          where: fragment("date(?)", p.published_at) != fragment("date(?)", ago(^1, "month"))
        )

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{not: %{==: %{date: %{ago: [count: 1, interval: "month"]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic + variants" do
    test "views == views + 10 (plain)" do
      expected = from(p in Post, where: p.views == p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views != views + 10 (plain)" do
      expected = from(p in Post, where: p.views != p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{!=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views > views + 10 (plain)" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views >= views + 10 (plain)" do
      expected = from(p in Post, where: p.views >= p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views < views + 10 (plain)" do
      expected = from(p in Post, where: p.views < p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{<: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "views <= views + 10 (plain)" do
      expected = from(p in Post, where: p.views <= p.views + ^10)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{<=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views != views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views != p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{!=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views >= views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views >= p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views < views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views < p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{<: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views <= views + 10) (negated)" do
      expected = from(p in Post, where: not (p.views <= p.views + ^10))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{<=: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic - variants" do
    test "views == views - 5 (plain)" do
      expected = from(p in Post, where: p.views == p.views - ^5)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{-: [%{field: "views"}, %{value: 5}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views == views - 5) (negated)" do
      expected = from(p in Post, where: not (p.views == p.views - ^5))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{-: [%{field: "views"}, %{value: 5}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic * variants" do
    test "views == views * 2 (plain)" do
      expected = from(p in Post, where: p.views == p.views * ^2)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{*: [%{field: "views"}, %{value: 2}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views == views * 2) (negated)" do
      expected = from(p in Post, where: not (p.views == p.views * ^2))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{==: %{value: %{*: [%{field: "views"}, %{value: 2}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end

  describe "arithmetic / variants" do
    test "views == views / 2 (plain)" do
      expected = from(p in Post, where: p.views == p.views / ^2)

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{==: %{value: %{/: [%{field: "views"}, %{value: 2}]}}}},
          []
        )

      assert_sql(expected, q2)
    end

    test "not (views >= views / 2) (negated)" do
      expected = from(p in Post, where: not (p.views >= p.views / ^2))

      q2 =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>=: %{value: %{/: [%{field: "views"}, %{value: 2}]}}}}},
          []
        )

      assert_sql(expected, q2)
    end
  end
end
