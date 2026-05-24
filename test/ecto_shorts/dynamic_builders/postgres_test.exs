defmodule EctoShorts.DynamicBuilders.PostgresTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.DynamicBuilders.Postgres
  alias EctoShorts.Schema.EnumSchema
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "build_dynamic/4 quantifier operators" do
    test "builds :all quantifier expression for a single field" do
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:all, [published: true]})

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test "builds :any quantifier expression for a single field" do
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:any, [published: true]})

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test "returns nil when quantifier params normalize to empty" do
      result = Postgres.build_dynamic(Post, {:as, nil}, {:any, []})

      assert is_nil(result)
    end
  end

  describe "build_dynamic/4 merge ops (:and/:or entries)" do
    test "builds expression when entry has :or merge op from or-group" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{or: [published: true, views: %{>: 0}]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "build_dynamic/4 :and/:or merge ops in params list" do
    test ":or entry in params list produces an OR-merged dynamic expression" do
      actual =
        Postgres.build_dynamic(Post, {:as, nil}, {:views, [and: {:<, 10}, or: {:>, 5}]}, [])

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test ":and entry in params list produces a dynamic expression" do
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:views, [and: {:>, 0}]}, [])

      assert %Ecto.Query.DynamicExpr{} = actual
    end
  end

  describe "build_dynamic/4 nil dynamic handling" do
    import ExUnit.CaptureLog

    test "nil dynamic from an invalid field is skipped when accumulating :all quantifier results" do
      log =
        capture_log(fn ->
          result =
            Postgres.build_dynamic(
              Post,
              {:as, nil},
              {:all, [published: true, nonexistent_xyz: 5]},
              []
            )

          assert %Ecto.Query.DynamicExpr{} = result
        end)

      assert log =~ "Field"
      assert log =~ "does not exist on schema"
    end
  end

  describe "build_dynamic/4 non-quantified payload values" do
    test "empty list payload is not treated as a quantified query" do
      result = Postgres.build_dynamic(Post, {:as, nil}, {:id, {:any, []}}, [])

      assert is_nil(result)
    end

    test "non-list non-map payload is not treated as a quantified query" do
      result = Postgres.build_dynamic(Post, {:as, nil}, {:id, {:any, :not_a_payload}}, [])

      assert is_nil(result)
    end
  end

  describe "build_quantified_query/3 when params is not a keyword list" do
    test "warns and returns params when params is not a keyword list" do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          result = Postgres.build_quantified_query(:id, "not_a_keyword_list", [])
          assert result == "not_a_keyword_list"
        end)

      assert log =~ "Expected a map or keyword list"
    end
  end

  describe "build_quantified_query/3 with a binary select spec" do
    test "resolves a binary select spec to the correct select field" do
      result = Postgres.build_quantified_query(:id, [from: Post, select: "id"], [])
      assert %Ecto.Query{} = result
    end
  end

  describe "build_quantified_query/3 with a map select spec" do
    test "uses the :field value from a map select spec as the select field" do
      result = Postgres.build_quantified_query(:id, [from: Post, select: %{field: :id}], [])
      assert %Ecto.Query{} = result
    end
  end

  describe "build_quantified_query/3 with an unrecognized select spec type" do
    test "falls back to the outer key when select spec is not an atom, binary, or map" do
      result = Postgres.build_quantified_query(:id, [from: Post, select: 42], [])
      assert %Ecto.Query{} = result
    end
  end

  describe "cast_value for array field with :all tuple form" do
    test "casts inner value when :all wraps a comparison tuple" do
      result = Postgres.build_dynamic(Post, {:as, nil}, {:tags, [{:all, {:>, "a"}}]}, [])

      assert %Ecto.Query.DynamicExpr{} = result
    end
  end

  describe "build_dynamic/4 Ecto.Enum casting" do
    test "casts a bare Ecto.Enum atom to its integer mapping" do
      expected = dynamic([q], field(q, :status) == ^1)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, :published})

      assert_dynamic(expected, actual)
    end

    test "casts an operator-wrapped Ecto.Enum atom" do
      expected = dynamic([q], field(q, :status) != ^2)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, {:!=, :archived}})

      assert_dynamic(expected, actual)
    end

    test "casts a list of Ecto.Enum atoms for membership" do
      expected = dynamic([q], field(q, :status) in ^[1, 2])
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, [:published, :archived]})

      assert_dynamic(expected, actual)
    end

    test "passes through values that do not need casting" do
      expected = dynamic([q], field(q, :views) == ^42)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:views, 42})

      assert_dynamic(expected, actual)
    end

    test "passes through nil without casting" do
      expected = dynamic([q], is_nil(field(q, :status)))
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, nil})

      assert_dynamic(expected, actual)
    end

    test "casts a string integer for a scalar field" do
      expected = dynamic([q], field(q, :id) == ^1)
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:id, "1"})

      assert_dynamic(expected, actual)
    end

    test "casts an operator-wrapped string integer" do
      expected = dynamic([q], field(q, :views) > ^10)
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:views, {:>, "10"}})

      assert_dynamic(expected, actual)
    end

    test "casts a list of string integers for membership" do
      expected = dynamic([q], field(q, :id) in ^[1, 2, 3])
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:id, ["1", "2", "3"]})

      assert_dynamic(expected, actual)
    end
  end
end
