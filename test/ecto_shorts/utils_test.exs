defmodule EctoShorts.UtilsTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Utils

  describe "atomize_keys/1" do
    test "passes through string-keyed maps preserving keys" do
      result = Utils.atomize_keys(%{"title" => "Hello"})

      assert result === %{"title" => "Hello"}
    end

    test "passes through atom-keyed maps unchanged" do
      result = Utils.atomize_keys(%{title: "Hello"})

      assert result === %{title: "Hello"}
    end

    test "recursively transforms nested maps" do
      result = Utils.atomize_keys(%{nested: %{inner: "value"}})

      assert result === %{nested: %{inner: "value"}}
    end

    test "recursively traverses deeply nested structures" do
      result = Utils.atomize_keys(%{a: %{b: %{c: "deep"}}})

      assert result === %{a: %{b: %{c: "deep"}}}
    end

    test "preserves scalar values in list inputs" do
      result = Utils.atomize_keys([{"title", "Hello"}, {"views", 10}])

      assert result === [{"title", "Hello"}, {"views", 10}]
    end

    test "preserves a bare tuple input" do
      result = Utils.atomize_keys({"title", "Hello"})

      assert result === {"title", "Hello"}
    end

    test "passes scalar values through unchanged" do
      assert Utils.atomize_keys(42) === 42
      assert Utils.atomize_keys("string") === "string"
      assert Utils.atomize_keys(:atom) === :atom
      assert Utils.atomize_keys(nil) === nil
    end

    # The {key, value} branch in the transform lambda is triggered when a map has a
    # tuple as its key (e.g. %{{"string_key", extra} => value}). In that case fun/1
    # is called with the whole {string, extra} tuple, matching the {key, value} clause.

    test "converts the tuple key's string part to an atom when the atom already exists" do
      # :title is a well-known atom in this project so String.to_existing_atom succeeds.
      result = Utils.atomize_keys(%{{"title", :extra} => "value"})

      assert Map.has_key?(result, {:title, :extra})
      assert result[{:title, :extra}] === "value"
    end

    test "keeps the tuple key's string part as a string when the atom does not exist" do
      nonexistent = "ecto_shorts_nonexistent_xyzzy_#{System.unique_integer([:positive])}"
      result = Utils.atomize_keys(%{{nonexistent, :extra} => "value"})

      assert Map.has_key?(result, {nonexistent, :extra})
      assert result[{nonexistent, :extra}] === "value"
    end
  end
end
