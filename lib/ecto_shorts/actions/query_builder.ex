defmodule EctoShorts.Actions.QueryBuilder do
  @moduledoc """
  Behaviour for query building from a filter map.
  Allows calling custom query functions in schemas
  by defining the callback in a context.

  In other words, the query builder decides how and when to apply
  a schema's query function.

  Example of implementing the `build_query/3` callback in a context:
  ```elixir
    defmodule YourApp.Context do
      @behaviour EctoShorts.Actions.QueryBuilder

      @impl EctoShorts.Actions.QueryBuilder
      def build_query(YourApp.Context.Schema, {:custom_filter, val}, queryable) do
        YourApp.Context.Schema.by_custom_filter(queryable, val)
      end
    end
  ```
  """

  @type filter :: %{(filter_key :: atom) => filter_value :: any}
  @type queryable :: Ecto.Queryable.t()
  @type schema :: module()

  @doc "Adds condition to accumulator Ecto query by calling schema's function"
  @callback build_query(schema, filter, queryable) :: queryable
  @callback filters() :: list(atom)
end
