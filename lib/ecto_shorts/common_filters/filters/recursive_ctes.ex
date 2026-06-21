defmodule EctoShorts.CommonFilters.RecursiveCtes do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:recursive_ctes` structural filter for `EctoShorts.CommonFilters`.

  Enables or disables recursive CTE evaluation for the query by calling
  `Ecto.Query.recursive_ctes/2`. The value is cast to a boolean. Used together
  with `:with_cte` to build recursive common table expressions. Used via params,
  not called directly:

      EctoShorts.Actions.all(Category, %{recursive_ctes: true, with_cte: [...]})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.Types
  alias Ecto.Query

  def build_query(:recursive_ctes, _source, query, _selected_binding, value, _opts) do
    Query.recursive_ctes(query, Types.cast(:boolean, value))
  end
end
