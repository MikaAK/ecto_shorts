defmodule EctoShorts.QueryBindingTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonFilters
  alias EctoShorts.QueryBinding
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  @out_of_range_position 11
  use EctoShorts.Testing
  import Ecto.Query



  describe "query_binding_contracts/2" do
    test "exposes root, named, and positional binding contracts" do
      {target_binding_var, binding_patterns} =
        QueryBinding.query_binding_contracts(__MODULE__, positions: 2)

      assert "q" = Macro.to_string(target_binding_var)

      assert [
               {"{:as, nil}", ["q"]},
               {"{:as, binding_alias}", ["{^binding_alias, q}"]},
               {"{:at, 1}", ["q"]},
               {"{:at, 2}", ["_", "q"]}
             ] =
               Enum.map(binding_patterns, fn {binding_head, binding_body} ->
                 {Macro.to_string(binding_head), Enum.map(binding_body, &Macro.to_string/1)}
               end)
    end
  end

  describe "dyn_expr/4 with positional binding" do
    test "generates a dynamic/2 call with a positional binding variable list" do
      q_var = Macro.var(:q, __MODULE__)
      field_expr = quote do: field(q, :views) === 5

      result = QueryBinding.dyn_expr({:at, 2}, q_var, field_expr, __MODULE__)

      # The result is a quoted AST for a dynamic/2 call — verify it has the
      # right structure without evaluating it.
      assert {:dynamic, _, _} = result
    end

    test "generates a single-element binding list for positional index 1" do
      q_var = Macro.var(:q, __MODULE__)
      field_expr = quote do: field(q, :id) === 1

      result = QueryBinding.dyn_expr({:at, 1}, q_var, field_expr, __MODULE__)

      assert {:dynamic, _, _} = result
    end
  end

  # ---- merged from out_of_range_binding ----
  describe "raises on out-of-range :at field filters (D-RAISE)" do
    @describetag feature: :out_of_range_binding
    test "field filter at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments))

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{title: "hello"}}},
          []
        )
      end
    end

    test "position zero raises" do
      base_query = from(p in Post)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{0 => %{title: "hello"}}},
          []
        )
      end
    end

    test "negative position raises" do
      base_query = from(p in Post)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{-1 => %{title: "hello"}}},
          []
        )
      end
    end
  end

  describe "raises on out-of-range :at structural filters (D-RAISE)" do
    @describetag feature: :out_of_range_binding
    test "having at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments), group_by: p.id)

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{having: %{views: %{avg: %{>: 100}}}}}},
          []
        )
      end
    end

    test "order_by at out-of-range position raises" do
      base_query = from(p in Post, join: c in assoc(p, :comments))

      assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{@out_of_range_position => %{order_by: :title}}},
          []
        )
      end
    end
  end

  describe "still applies in-range :at positions" do
    @describetag feature: :out_of_range_binding
    test "position within max applies the filter normally" do
      base_query =
        from(p in Post,
          join: c in assoc(p, :comments)
        )

      expected =
        from(p in Post,
          join: c in assoc(p, :comments),
          where: c.published == ^true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          base_query,
          %{at: %{2 => %{published: true}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from parent_as ----
  describe "parent_as equality" do
    @describetag feature: :parent_as
    test "matches Ecto.Query for a root binding equality" do
      expected = from(c in Comment, where: c.post_id == field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          Comment,
          %{post_id: %{parent_as: %{post: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated root binding equality" do
      expected = from(c in Comment, where: c.post_id != field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          Comment,
          %{post_id: %{not: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "parent_as comparison operators" do
    @describetag feature: :parent_as
    test "matches Ecto.Query for a greater-than comparison" do
      expected = from(p in Post, where: p.views > field(parent_as(:post), :views))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{parent_as: %{post: :views}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated greater-than comparison" do
      expected = from(p in Post, where: not (p.views > field(parent_as(:post), :views)))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>: %{parent_as: %{post: :views}}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "parent_as named binding" do
    @describetag feature: :parent_as
    test "matches Ecto.Query for a named binding equality" do
      source = from(c in Comment, join: p in assoc(c, :post), as: :post_join)

      expected =
        from(c in Comment,
          join: p in assoc(c, :post),
          as: :post_join,
          where: p.id == field(parent_as(:post), :id)
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{post_join: %{id: %{parent_as: %{post: :id}}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from parent_as (schemaless) ----
  describe "parent_as equality (schemaless)" do
    @describetag feature: :parent_as
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root binding equality" do
      expected = from(c in "comments", where: c.post_id == field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{parent_as: %{post: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated root binding equality" do
      expected = from(c in "comments", where: c.post_id != field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{not: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a greater-than comparison" do
      expected = from(c in "comments", where: c.id > field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{id: %{>: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
