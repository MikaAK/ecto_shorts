defmodule EctoShorts.CommonFilters.ParserTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonFilters.Parser

  doctest EctoShorts.CommonFilters.Parser

  describe "normalize/1" do
    test "normalizes a single-level pair list" do
      assert Parser.normalize([{"a", 1}, {"b", 2}]) === [{"a", 1}, {"b", 2}]
    end

    test "normalizes a nested pair list" do
      assert Parser.normalize([{"a", 1}, {"b", [{"c", 2}]}]) === [{"a", 1}, {"b", {"c", 2}}]
    end

    test "normalizes a deeply nested pair list" do
      assert Parser.normalize([{"a", 1}, {"b", [{"c", 2}, {"d", [{"e", 3}]}]}]) ===
               [{"a", 1}, {"b", {"c", 2}}, {"b", {"d", {"e", 3}}}]
    end

    test "fans a multi-key sub-list into one entry per leaf" do
      assert Parser.normalize([{"a", 1}, {"b", [{"c", 2}, {"d", 3}]}]) ===
               [{"a", 1}, {"b", {"c", 2}}, {"b", {"d", 3}}]
    end

    test "returns an empty list for an empty map" do
      assert Parser.normalize(%{}) === []
    end

    test "returns a single-element list for a bare string" do
      assert Parser.normalize("string") === ["string"]
    end

    test "returns a single-element list for a bare integer" do
      assert Parser.normalize(123) === [123]
    end

    test "returns the list unchanged for a flat list of bare values" do
      assert Parser.normalize([1, 2, 3]) === [1, 2, 3]
    end
  end

  describe "normalize/2 with predicate" do
    test "identity predicate matches no-arg behavior on a flat pair list" do
      always_true = fn _, _ -> true end

      assert Parser.normalize([{"a", 1}, {"b", 2}], always_true) === [{"a", 1}, {"b", 2}]
    end

    test "identity predicate matches no-arg behavior on a nested pair list" do
      always_true = fn _, _ -> true end

      assert Parser.normalize([{"a", 1}, {"b", [{"c", 2}]}], always_true) ===
               [{"a", 1}, {"b", {"c", 2}}]
    end

    test "identity predicate matches no-arg behavior on an empty map" do
      always_true = fn _, _ -> true end

      assert Parser.normalize(%{}, always_true) === []
    end

    test "false-everywhere predicate stops at top level, leaving values unchanged" do
      always_false = fn _, _ -> false end

      assert Parser.normalize([{"a", 1}, {"b", %{"c" => %{"d" => 2}}}], always_false) ===
               [{"a", 1}, {"b", %{"c" => %{"d" => 2}}}]
    end

    test "predicate halts expansion at the chosen key, mid-tree" do
      stop_at_c = fn key, _value -> key != "c" end

      assert Parser.normalize([{"a", 1}, {"b", [{"c", %{"d" => 2}}]}], stop_at_c) ===
               [{"a", 1}, {"b", {"c", %{"d" => 2}}}]
    end

    test "predicate is consulted at every recursion level, not just the top" do
      stop_at_stop = fn key, _value -> key != "stop" end

      assert Parser.normalize(
               [{"outer", [{"stop", %{"deep" => 1}}, {"keep", 2}]}],
               stop_at_stop
             ) ===
               [
                 {"outer", {"stop", %{"deep" => 1}}},
                 {"outer", {"keep", 2}}
               ]
    end

    test "predicate sees the value as the second argument" do
      stop_when_value_is_map = fn _key, value -> not is_map(value) end

      assert Parser.normalize(
               [{"a", %{"x" => 1}}, {"b", [{"c", 1}]}],
               stop_when_value_is_map
             ) ===
               [
                 {"a", %{"x" => 1}},
                 {"b", {"c", 1}}
               ]
    end

    test "rejects predicates with the wrong arity" do
      assert_raise FunctionClauseError, fn ->
        Parser.normalize(%{"a" => 1}, fn _ -> true end)
      end
    end
  end

  describe "normalize/3 with explicit acc" do
    test "predicate identity with explicit empty acc matches default on a pair list" do
      always_true = fn _, _ -> true end

      assert Parser.normalize([{"a", 1}, {"b", [{"c", 2}]}], always_true, []) ===
               [{"a", 1}, {"b", {"c", 2}}]
    end
  end
end
