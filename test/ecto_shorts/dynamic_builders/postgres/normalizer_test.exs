defmodule EctoShorts.DynamicBuilders.Postgres.NormalizerTest do
  use ExUnit.Case, async: true

  alias EctoShorts.DynamicBuilders.Postgres.Normalizer
  alias EctoShorts.Schema.Post

  describe "normalize_params/3" do
    test "passes a plain scalar through as a single-element list" do
      assert [true] = Normalizer.normalize_params(nil, true, [])
      assert [42] = Normalizer.normalize_params(nil, 42, [])
      assert ["hello"] = Normalizer.normalize_params(nil, "hello", [])
    end

    test "converts a map to a keyword list and normalizes" do
      assert [{:title, "hello"}] = Normalizer.normalize_params(nil, %{title: "hello"}, [])
    end

    test "flattens a keyword list" do
      assert [{:title, "hello"}, {:published, true}] =
               Normalizer.normalize_params(nil, [title: "hello", published: true], [])
    end

    test "preserves quantifier operators" do
      result = Normalizer.normalize_params(nil, [all: [:a, :b]], [])
      assert [{:all, [:a, :b]}] = result
    end

    test "preserves arithmetic value operators as value nodes" do
      result = Normalizer.normalize_params(nil, [+: [1, 2]], [])
      assert [{:+, {1, 2}}] = result
    end

    test "preserves datetime wrapper operators as value nodes" do
      result = Normalizer.normalize_params(nil, [datetime: [add: [count: 1, interval: :day]]], [])
      assert [{:datetime, {:add, [count: 1, interval: :day]}}] = result
    end

    test "recursively normalizes nested keyword values" do
      result = Normalizer.normalize_params(nil, [views: [>: 10]], [])
      assert [{:views, {:>, 10}}] = result
    end

    test "normalizes an atom field name inside a field marker" do
      result = Normalizer.normalize_params(nil, [inserted_at: %{field: :inserted_at}], [])
      assert [{:inserted_at, {:field, :inserted_at}}] = result
    end

    test "normalizes a string field name inside a field marker using schema validation" do
      result = Normalizer.normalize_value_node(Post, {:field, "views"}, [])
      assert {:field, :views} = result
    end
  end

  describe "normalize_value_node/3" do
    test "passes scalars through unchanged" do
      assert 42 = Normalizer.normalize_value_node(nil, 42, [])
      assert :foo = Normalizer.normalize_value_node(nil, :foo, [])
      assert "bar" = Normalizer.normalize_value_node(nil, "bar", [])
      assert nil === Normalizer.normalize_value_node(nil, nil, [])
    end

    test "converts a map to a list and re-normalizes" do
      assert [{:a, 1}] = Normalizer.normalize_value_node(nil, %{a: 1}, [])
    end

    test "normalizes {:field, atom_name}" do
      assert {:field, :inserted_at} =
               Normalizer.normalize_value_node(nil, {:field, :inserted_at}, [])
    end

    test "normalizes {:field, binary_name} using fallback (existing atom)" do
      assert {:field, :inserted_at} =
               Normalizer.normalize_value_node(nil, {:field, "inserted_at"}, [])
    end

    test "normalizes {:value, inner}" do
      assert {:value, 5} = Normalizer.normalize_value_node(nil, {:value, 5}, [])
    end

    test "normalizes arithmetic operator node {op, [left, right]}" do
      assert {:+, {1, 2}} = Normalizer.normalize_value_node(nil, {:+, [1, 2]}, [])
      assert {:-, {10, 3}} = Normalizer.normalize_value_node(nil, {:-, [10, 3]}, [])
      assert {:*, {4, 5}} = Normalizer.normalize_value_node(nil, {:*, [4, 5]}, [])
      assert {:/, {10, 2}} = Normalizer.normalize_value_node(nil, {:/, [10, 2]}, [])
    end

    test "raises for arithmetic node with wrong arity" do
      assert_raise ArgumentError, ~r/two-element list/, fn ->
        Normalizer.normalize_value_node(nil, {:+, [1]}, [])
      end
    end

    test "normalizes datetime wrapper {:datetime, payload}" do
      assert {:datetime, {:add, [count: 1, interval: :day]}} =
               Normalizer.normalize_value_node(
                 nil,
                 {:datetime, [add: [count: 1, interval: :day]]},
                 []
               )
    end

    test "normalizes datetime wrapper {:date, payload}" do
      assert {:date, {:ago, [count: 7, interval: :day]}} =
               Normalizer.normalize_value_node(
                 nil,
                 {:date, [ago: [count: 7, interval: :day]]},
                 []
               )
    end

    test "raises for datetime wrapper with unrecognized operation" do
      assert_raise ArgumentError, ~r/datetime/, fn ->
        Normalizer.normalize_value_node(
          nil,
          {:datetime, [unknown: [count: 1, interval: :day]]},
          []
        )
      end
    end

    test "normalizes datetime operation node {op, params}" do
      assert {:add, [count: 5, interval: :hour]} =
               Normalizer.normalize_value_node(nil, {:add, [count: 5, interval: :hour]}, [])
    end

    test "normalizes datetime operation node with atom field" do
      assert {:ago, [field: :inserted_at, count: 3, interval: :day]} =
               Normalizer.normalize_value_node(
                 nil,
                 {:ago, [field: :inserted_at, count: 3, interval: :day]},
                 []
               )
    end

    test "normalizes field: shorthand keyword" do
      assert {:field, :title} = Normalizer.normalize_value_node(nil, [field: :title], [])
    end

    test "normalizes value: shorthand keyword" do
      assert {:value, 99} = Normalizer.normalize_value_node(nil, [value: 99], [])
    end

    test "normalizes empty list" do
      assert [] = Normalizer.normalize_value_node(nil, [], [])
    end

    test "recursively normalizes a list" do
      assert [{:field, :title}, 42] =
               Normalizer.normalize_value_node(nil, [{:field, :title}, 42], [])
    end
  end

  describe "normalize_datetime_node/3" do
    test "accepts a keyword list with count and interval" do
      assert [count: 1, interval: :day] =
               Normalizer.normalize_datetime_node(nil, [count: 1, interval: :day], [])
    end

    test "accepts a keyword list with atom field, count, and interval" do
      assert [field: :inserted_at, count: 2, interval: :hour] =
               Normalizer.normalize_datetime_node(
                 nil,
                 [field: :inserted_at, count: 2, interval: :hour],
                 []
               )
    end

    test "accepts a map and normalizes it" do
      assert [count: 5, interval: :minute] =
               Normalizer.normalize_datetime_node(nil, %{count: 5, interval: :minute}, [])
    end

    test "normalizes string field name inside datetime node using schema validation" do
      result =
        Normalizer.normalize_datetime_node(
          Post,
          [field: "inserted_at", count: 1, interval: :day],
          []
        )

      assert [field: :inserted_at, count: 1, interval: :day] = result
    end

    test "raises for a non-keyword list" do
      assert_raise ArgumentError, ~r/keyword list or map/, fn ->
        Normalizer.normalize_datetime_node(nil, [:a, :b], [])
      end
    end
  end

  describe "normalize_keyword_params/4" do
    test "returns empty list for empty input" do
      assert [] = Normalizer.normalize_keyword_params(nil, [], [], [])
    end

    test "preserves quantifier entries" do
      assert [{:all, [1, 2]}] = Normalizer.normalize_keyword_params(nil, [{:all, [1, 2]}], [], [])
      assert [{:any, :foo}] = Normalizer.normalize_keyword_params(nil, [{:any, :foo}], [], [])
    end

    test "preserves arithmetic operator entries as value nodes" do
      assert [{:+, {1, 2}}] = Normalizer.normalize_keyword_params(nil, [{:+, [1, 2]}], [], [])
    end

    test "preserves datetime wrapper entries as value nodes" do
      assert [{:datetime, {:add, [count: 1, interval: :day]}}] =
               Normalizer.normalize_keyword_params(
                 nil,
                 [{:datetime, [add: [count: 1, interval: :day]]}],
                 [],
                 []
               )
    end

    test "flattens a regular key/value pair" do
      assert [{:title, "hello"}] =
               Normalizer.normalize_keyword_params(nil, [{:title, "hello"}], [], [])
    end

    test "returns entries in original order" do
      result = Normalizer.normalize_keyword_params(nil, [a: 1, b: 2, c: 3], [], [])
      assert [{:a, 1}, {:b, 2}, {:c, 3}] = result
    end
  end

  describe "normalize_operator/1 aliases" do
    test ":downcase normalizes to :lower" do
      assert :lower = Normalizer.normalize_operator(:downcase)
    end

    test ":upcase normalizes to :upper" do
      assert :upper = Normalizer.normalize_operator(:upcase)
    end

    test "existing aliases are unchanged" do
      assert :== = Normalizer.normalize_operator(:eq)
      assert :!= = Normalizer.normalize_operator(:ne)
      assert :> = Normalizer.normalize_operator(:gt)
      assert :>= = Normalizer.normalize_operator(:gte)
      assert :< = Normalizer.normalize_operator(:lt)
      assert :<= = Normalizer.normalize_operator(:lte)
    end

    test "unrecognized atoms pass through" do
      assert :lower = Normalizer.normalize_operator(:lower)
      assert :upper = Normalizer.normalize_operator(:upper)
      assert :in = Normalizer.normalize_operator(:in)
    end
  end

  describe ":aggregate wrapper" do
    test "normalizes fn:, compare:, value: map to {fn, {op, value}}" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:aggregate, %{fn: :avg, compare: :>, value: 5}}],
          [],
          []
        )

      assert [{:avg, {:>, 5}}] = result
    end

    test "accepts a keyword list payload" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:aggregate, [fn: :sum, compare: :>=, value: 100]}],
          [],
          []
        )

      assert [{:sum, {:>=, 100}}] = result
    end

    test "normalizes the compare operator alias" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:aggregate, %{fn: :count, compare: :gt, value: 0}}],
          [],
          []
        )

      assert [{:count, {:>, 0}}] = result
    end

    test "supports all aggregate functions" do
      for fn_name <- [:avg, :sum, :min, :max, :count] do
        result =
          Normalizer.normalize_keyword_params(
            nil,
            [{:aggregate, %{fn: fn_name, compare: :==, value: 0}}],
            [],
            []
          )

        assert [{^fn_name, {:==, 0}}] = result
      end
    end

    test "is produced by normalize_params on a field aggregate map" do
      result =
        Normalizer.normalize_params(
          nil,
          %{score: %{aggregate: %{fn: :avg, compare: :>, value: 5}}},
          []
        )

      assert [{:score, {:avg, {:>, 5}}}] = result
    end
  end

  describe ":arithmetic wrapper - numeric" do
    test "add: produces {:>, {:value, {:+, {left, right}}}}" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>, add: %{field: :base_score, value: 5}}}],
          [],
          []
        )

      assert [{:>, {:value, {:+, {{:field, :base_score}, {:value, 5}}}}}] = result
    end

    test "subtract: produces :- internal op" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>, subtract: %{field: :base, value: 3}}}],
          [],
          []
        )

      assert [{:>, {:value, {:-, {{:field, :base}, {:value, 3}}}}}] = result
    end

    test "multiply: produces :* internal op" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>=, multiply: %{field: :base, value: 2}}}],
          [],
          []
        )

      assert [{:>=, {:value, {:*, {{:field, :base}, {:value, 2}}}}}] = result
    end

    test "divide: produces :/ internal op" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :<, divide: %{field: :base, value: 4}}}],
          [],
          []
        )

      assert [{:<, {:value, {:/, {{:field, :base}, {:value, 4}}}}}] = result
    end

    test "compare operator alias is normalized" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :gte, add: %{field: :base, value: 1}}}],
          [],
          []
        )

      assert [{:>=, {:value, {:+, _}}}] = result
    end

    test "is produced by normalize_params on a field arithmetic map" do
      result =
        Normalizer.normalize_params(
          nil,
          %{score: %{arithmetic: %{compare: :>, add: %{field: :base_score, value: 5}}}},
          []
        )

      assert [{:score, {:>, {:value, {:+, {{:field, :base_score}, {:value, 5}}}}}}] = result
    end
  end

  describe ":arithmetic wrapper - datetime" do
    test "ago: with interval: produces {:datetime, {:ago, params}}" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>, ago: %{count: 7, interval: "day"}}}],
          [],
          []
        )

      assert [{:>, {:datetime, {:ago, [count: 7, interval: "day"]}}}] = result
    end

    test "from_now: with interval: produces {:datetime, {:from_now, params}}" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :<, from_now: %{count: 1, interval: "month"}}}],
          [],
          []
        )

      assert [{:<, {:datetime, {:from_now, [count: 1, interval: "month"]}}}] = result
    end

    test "add: with interval: produces {:datetime, {:add, params}} (not numeric)" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>=, add: %{count: 1, interval: "hour"}}}],
          [],
          []
        )

      assert [{:>=, {:datetime, {:add, [count: 1, interval: "hour"]}}}] = result
    end

    test "cast: :date wraps in :date instead of :datetime" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>, ago: %{count: 30, interval: "day", cast: :date}}}],
          [],
          []
        )

      assert [{:>, {:date, {:ago, [count: 30, interval: "day"]}}}] = result
    end

    test "cast: :date is stripped from the datetime params" do
      [{:>, {:date, {:ago, params}}}] =
        Normalizer.normalize_keyword_params(
          nil,
          [{:arithmetic, %{compare: :>, ago: %{count: 30, interval: "day", cast: :date}}}],
          [],
          []
        )

      refute Keyword.has_key?(params, :cast)
    end
  end

  describe ":elements wrapper" do
    test "normalizes inner term and preserves :elements wrapper" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:elements, %{in: ["a", "b"]}}],
          [],
          []
        )

      assert [{:elements, [{:in, ["a", "b"]}]}] = result
    end

    test "normalizes a scalar inner term" do
      result = Normalizer.normalize_keyword_params(nil, [{:elements, "elixir"}], [], [])
      assert [{:elements, ["elixir"]}] = result
    end

    test "normalizes nil inner term" do
      result = Normalizer.normalize_keyword_params(nil, [{:elements, nil}], [], [])
      assert [{:elements, [nil]}] = result
    end

    test "normalizes count operator inside elements" do
      result =
        Normalizer.normalize_keyword_params(
          nil,
          [{:elements, %{count: %{>: 3}}}],
          [],
          []
        )

      assert [{:elements, [{:count, {:>, 3}}]}] = result
    end

    test "is produced by normalize_params on a field elements map" do
      result = Normalizer.normalize_params(nil, %{tags: %{elements: %{in: ["a", "b"]}}}, [])
      assert [{:tags, {:elements, [{:in, ["a", "b"]}]}}] = result
    end
  end
end
