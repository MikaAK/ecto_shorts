defmodule EctoShorts.QueryBuilders.CommonTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilders.Common

  alias EctoShorts.QueryBuilders.Common
  alias EctoShorts.Support.Schema.Comment

  describe "filters: " do
    test "returns expected list" do
      assert [
               :after,
               :before,
               :end_date,
               :first,
               :ids,
               :last,
               :limit,
               :offset,
               :order_by,
               :preload,
               :search,
               :since,
               :start_date,
               :until
             ] = Common.filters()
    end
  end

  describe "build_query: " do
    test "returns query without changes when passed {:search, term()}" do
      assert Comment = Common.build_query(Comment, nil, Comment, :search, %{id: 1}, [])
    end
  end
end
