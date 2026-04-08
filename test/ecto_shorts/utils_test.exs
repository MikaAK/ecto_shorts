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
  end
end
