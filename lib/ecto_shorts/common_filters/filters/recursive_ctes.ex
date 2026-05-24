defmodule EctoShorts.CommonFilters.RecursiveCtes do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.Types
  alias Ecto.Query

  def build_query(:recursive_ctes, _source, query, _selected_binding, value, _opts) do
    Query.recursive_ctes(query, Types.cast(:boolean, value))
  end
end
