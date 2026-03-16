defmodule EctoShorts.QueryBindingTest do
  use ExUnit.Case, async: true

  alias EctoShorts.QueryBinding

  test "query_binding_contracts/2 exposes root, named, and positional binding contracts" do
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
