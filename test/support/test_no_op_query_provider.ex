defmodule EctoShorts.TestNoOpQueryProvider do
  def query_expression(_selected_binding, _expression_key, _expression_params, _opts) do
    nil
  end
end
