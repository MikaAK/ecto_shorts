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
  end
end
