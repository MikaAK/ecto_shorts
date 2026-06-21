defmodule EctoShorts.Actions.SourceTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Actions.Source

  describe "new/1" do
    test "builds a Source struct with the provided store" do
      result = Source.new(store: [posts: :posts_table, users: :users_table])
      assert %Source{store: %{posts: :posts_table, users: :users_table}} = result
    end

    test "builds a Source struct with an empty store when no store key is given" do
      assert %Source{store: %{}} = Source.new([])
    end
  end

  describe "fetch/2" do
    test "returns {:ok, value} when the key exists in the store" do
      source = Source.new(store: [users: :user_schema])
      assert {:ok, :user_schema} = Source.fetch(source, :users)
    end

    test "returns :error when the key is absent from the store" do
      source = Source.new(store: [users: :user_schema])
      assert :error = Source.fetch(source, :posts)
    end
  end
end
