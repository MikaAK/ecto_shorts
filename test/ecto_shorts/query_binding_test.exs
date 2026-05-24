defmodule EctoShorts.QueryBindingTest do
  use ExUnit.Case, async: true

  alias EctoShorts.QueryBinding

  describe "query_binding_contracts/2" do
    test "exposes root, named, and positional binding contracts" do
      {target_binding_var, binding_patterns} =
        QueryBinding.query_binding_contracts(__MODULE__, positions: 2)

      assert Macro.to_string(target_binding_var) === "q"

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
      field_expr = quote do: field(q, :views) == 5

      result = QueryBinding.dyn_expr({:at, 2}, q_var, field_expr, __MODULE__)

      # The result is a quoted AST for a dynamic/2 call — verify it has the
      # right structure without evaluating it.
      assert {:dynamic, _, _} = result
    end

    test "generates a single-element binding list for positional index 1" do
      q_var = Macro.var(:q, __MODULE__)
      field_expr = quote do: field(q, :id) == 1

      result = QueryBinding.dyn_expr({:at, 1}, q_var, field_expr, __MODULE__)

      assert {:dynamic, _, _} = result
    end
  end
end
