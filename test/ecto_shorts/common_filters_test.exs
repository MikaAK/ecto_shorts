defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :pipeline

  import Ecto.Query

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  defmodule AlwaysLimit99 do
    @behaviour EctoShorts.QueryBuilder
    def build_query(_filter, _source, query, _binding, _term, _opts) do
      import Ecto.Query
      from(q in query, limit: 99)
    end
  end

  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 query_builder: opt" do
    test "routes dispatch through a custom query builder when query_builder: is set" do
      expected = from(p in Post, limit: 99)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{limit: 5},
          query_builder: AlwaysLimit99
        )

      assert_query(expected, actual)
    end
  end

  describe "filters/0" do
    test "returns the list of supported filter keys" do
      filters = CommonFilters.filters()

      assert is_list(filters)
      assert :where in filters
      assert :limit in filters
      assert :offset in filters
    end
  end

  describe "convert_params_to_filter/3 custom sorter" do
    test "uses the provided sorter function to order params before applying" do
      # A sorter that reverses the params order — still produces a valid query
      sorter = fn params -> Enum.reverse(params) end

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [limit: 5, offset: 10],
          sorter: sorter
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "convert_params_to_filter/3 where with empty list" do
    test "returns query unchanged when where params is an empty list" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{where: []},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 join: nil" do
    test "returns query unchanged when join: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{join: nil}, [])

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 last: nil" do
    test "returns query unchanged when last: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{last: nil}, [])

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 or:/and: with scalar value" do
    test "returns query unchanged and warns when or: value is a scalar" do

      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{or: "bad"}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end

    test "returns query unchanged and warns when at: inner value is a scalar" do

      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{at: "bad"}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end

  describe "convert_params_to_filter/3 as: with scalar inner value" do
    test "returns query unchanged and does not crash when as: inner value is a scalar" do

      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(Post, %{as: %{title: "A"}}, [])

          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end

  describe "convert_params_to_filter/3 as:/at: nil" do
    test "returns query unchanged when as: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{as: nil}, [])

      assert_query(expected, actual)
    end

    test "returns query unchanged when at: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{at: nil}, [])

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 and:/or: nil" do
    test "returns query unchanged when and: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{and: nil}, [])

      assert_query(expected, actual)
    end

    test "returns query unchanged when or: value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{or: nil}, [])

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 where: nil" do
    test "returns query unchanged when where value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{where: nil},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when or_where value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{or_where: nil},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from association_filter ----
  describe "association filter shorthand" do
  @describetag feature: :association_filter
    test "routes a map value for a known association key through the association handler" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          where: a.age == ^25
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{author: %{age: 25}},
          []
        )

      assert_query(expected, actual)
    end

    test "routes a keyword list value for a known association key through the association handler" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          where: a.age == ^25
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [author: [age: 25]],
          []
        )

      assert_query(expected, actual)
    end

    test "raises when a known association key receives a scalar value (D-RAISE)" do
      assert_raise EctoShorts.FilterError, ~r/association/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{author: "bad value"}, [])
      end
    end
  end

  describe "sort_filter_params/1" do
    @describetag feature: :sorting
    test "orders where -> others -> or_where -> terminal, preserving within-group order" do
      params = [or_where: %{x: 1}, limit: 10, where: %{a: 1}, subquery: %{}, where: %{b: 2}, last: 5]

      assert CommonFilters.sort_filter_params(params) ===
               [where: %{a: 1}, where: %{b: 2}, limit: 10, or_where: %{x: 1}, subquery: %{}, last: 5]
    end
  end

  # ---- merged from association_filter (schemaless) ----
  describe "unknown key with scalar value (schemaless)" do
    @describetag feature: :association_filter
    @describetag schema_mode: :schemaless
    # For a schemaless source, `association_key?/2` always returns false because
    # there is no schema to reflect on. A key that would trigger association
    # shorthand on a schema source is treated as a plain field equality filter
    # instead. To join on a related table, the caller must use the explicit
    # `:join` filter key.
    test "treats an unknown key with a scalar value as a plain field equality filter" do
      expected = from(p in "posts", where: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{author_id: 1},
          []
        )

      assert_query(expected, actual)
    end
  end
end
