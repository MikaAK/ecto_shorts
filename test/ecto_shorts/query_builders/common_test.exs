defmodule EctoShorts.QueryBuilders.CommonTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilders.Common

  alias EctoShorts.QueryBuilders.Common
  alias EctoShorts.Schemas.Post

  import Ecto.Query, only: [from: 2, subquery: 1]
  import EctoShorts.Testing, only: [assert_query: 2]

  describe "filters: " do
    test "returns the list of supported filters" do
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
    test "builds a query with :ids filter for selecting specific IDs" do
      query = from c in Post, where: c.id in ^[1, 2, 3]
      assert_query query, Common.build_query(Post, nil, Post, :ids, [1, 2, 3])
    end

    test "builds a query with :first filter to apply a limit" do
      query = from c in Post, limit: ^1
      assert_query query, Common.build_query(Post, nil, Post, :first, 1)
    end

    test "builds a query with :last filter using subquery to order and limit results" do
      inner_query = from c in Post, order_by: [desc: c.inserted_at], limit: ^1
      outer_query = from c in subquery(inner_query), order_by: [asc: c.id]
      assert_query outer_query, Common.build_query(Post, nil, Post, :last, 1)
    end

    test "builds a query with :limit filter to limit results" do
      query = from c in Post, limit: ^1
      assert_query query, Common.build_query(Post, nil, Post, :limit, 1)
    end

    test "builds a query with :offset filter to skip results" do
      query = from c in Post, offset: ^1
      assert_query query, Common.build_query(Post, nil, Post, :offset, 1)
    end

    test "builds a query with :order_by filter to specify ordering" do
      query = from c in Post, order_by: [asc: c.id]
      assert_query query, Common.build_query(Post, nil, Post, :order_by, asc: :id)
    end

    test "builds a query with :preload filter to preload associations" do
      query = from c in Post, preload: [:comments]
      assert_query query, Common.build_query(Post, nil, Post, :preload, [:comments])
    end

    test "builds a query with :after filter to find entries with IDs greater than a given value" do
      query = from c in Post, where: c.id > ^1
      assert_query query, Common.build_query(Post, nil, Post, :after, 1)
    end

    test "builds a query with :before filter to find entries with IDs less than a given value" do
      query = from c in Post, where: c.id < ^1
      assert_query query, Common.build_query(Post, nil, Post, :before, 1)
    end

    test "builds a query with :since filter to find entries after a given date" do
      query = from c in Post, where: c.inserted_at >= ^~U[2025-05-26 00:00:00.000000Z]

      assert_query query,
                   Common.build_query(Post, nil, Post, :since, ~U[2025-05-26 00:00:00.000000Z])
    end

    test "builds a query with :until filter to find entries before a given date" do
      query = from c in Post, where: c.inserted_at <= ^~U[2025-05-26 00:00:00.000000Z]

      assert_query query,
                   Common.build_query(Post, nil, Post, :until, ~U[2025-05-26 00:00:00.000000Z])
    end

    test "builds a query with :start_date filter to find entries on or after a given date" do
      query = from c in Post, where: c.inserted_at >= ^~U[2025-05-26 00:00:00.000000Z]

      assert_query query,
                   Common.build_query(
                     Post,
                     nil,
                     Post,
                     :start_date,
                     ~U[2025-05-26 00:00:00.000000Z]
                   )
    end

    test "builds a query with :end_date filter to find entries on or before a given date" do
      query = from c in Post, where: c.inserted_at <= ^~U[2025-05-26 00:00:00.000000Z]

      assert_query query,
                   Common.build_query(Post, nil, Post, :end_date, ~U[2025-05-26 00:00:00.000000Z])
    end

    test "builds a query with :search filter to find entries by search criteria" do
      query = from p in Post, where: p.id == ^1
      assert_query query, Common.build_query(Post, nil, Post, :search, %{id: 1})
    end
  end
end
