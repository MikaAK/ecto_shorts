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
      result = Normalizer.normalize_params(nil, [{:inserted_at, {:field, :inserted_at}}], [])
      assert [{:inserted_at, {:field, :inserted_at}}] = result
    end

    test "normalizes a string field name inside a field marker using schema validation" do
      result = Normalizer.normalize_params(Post, [{:views, {:field, "views"}}], [])
      assert [{:views, {:field, :views}}] = result
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
end
