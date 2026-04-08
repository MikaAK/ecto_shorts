defmodule EctoShorts.CommonFilters.UpdateExprTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Ecto.Query

  alias EctoShorts.CommonFilters.UpdateExpr
  alias EctoShorts.Schema.Post

  describe "build_update_operations/3 invalid params" do
    test "logs a warning and returns [] when params is not a map or list" do
      log =
        capture_log(fn ->
          result = UpdateExpr.build_update_operations(Post, :invalid_atom)

          assert result == []
        end)

      assert log =~ "Expected params to be a map or list"
    end

    test "logs a warning and returns [] when params is a plain string" do
      log =
        capture_log(fn ->
          result = UpdateExpr.build_update_operations(Post, "not a map")

          assert result == []
        end)

      assert log =~ "Expected params to be a map or list"
    end
  end

  describe "build_update_expr/2 DynamicExpr input" do
    test "returns the dynamic expression unchanged" do
      dyn = dynamic([p], p.title == ^"hello")

      assert UpdateExpr.build_update_expr(Post, dyn) === dyn
    end
  end

  describe "build_update_expr/2 map input" do
    test "converts map to keyword list then processes as update expr" do
      result = UpdateExpr.build_update_expr(Post, %{set: %{title: "After"}})

      assert Keyword.keyword?(result)
      assert Keyword.has_key?(result, :set)
    end
  end

  describe "build_update_expr/2 list with non-update-operator keys" do
    test "returns params unchanged when list is not all update operators" do
      params = [{:unknown_op, "value"}]

      result = UpdateExpr.build_update_expr(Post, params)

      assert result == params
    end
  end

  describe "build_update_expr/2 invalid params" do
    test "logs a warning and returns the invalid value when params is not a map or list" do
      log =
        capture_log(fn ->
          result = UpdateExpr.build_update_expr(Post, :bad_params)

          assert result == :bad_params
        end)

      assert log =~ "Expected params to be a map or list"
    end
  end

  describe "build_update_expr/2 non-keyword list for cast_query_update_values" do
    test "returns values unchanged when set values is a plain (non-keyword) list" do
      # [set: ["a", "b"]] - set values is a plain list, not keyword
      result = UpdateExpr.build_update_expr(Post, set: ["a", "b"])

      assert result == [set: ["a", "b"]]
    end

    test "returns values unchanged when inc values is a plain (non-keyword) list" do
      result = UpdateExpr.build_update_expr(Post, inc: [1, 2])

      assert result == [inc: [1, 2]]
    end
  end

  describe "build_update_expr/2 push/pull with keyword values" do
    test "casts values for push operator on an array field" do
      result = UpdateExpr.build_update_expr(Post, push: [tags: "elixir"])

      assert [{:push, [tags: "elixir"]}] = result
    end

    test "casts values for push operator on an unknown field (no schema info)" do
      # When source is nil, array_inner_type returns nil -> value passed as-is
      result = UpdateExpr.build_update_expr(nil, push: [unknown_field: "val"])

      assert [{:push, [unknown_field: "val"]}] = result
    end
  end

  describe "build_update_expr/2 unknown op fallback in cast_query_update_values" do
    test "returns values unchanged for an unrecognized update operator" do
      # :delete is not in @update_operators so query_update_operator_entry? returns false
      # meaning build_update_expr returns params unchanged (the `else` branch)
      params = [{:delete, [title: "x"]}]

      result = UpdateExpr.build_update_expr(Post, params)

      assert result == params
    end
  end
end
