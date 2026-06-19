defmodule EctoShorts.CommonFilters.ReverseOrder do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  require Ecto.Query

  def build_query(:reverse_order, _source, query, _selected_binding, value, _opts) do
    case value do
      nil ->
        Query.reverse_order(query)

      true ->
        Query.reverse_order(query)

      _ ->
        raise EctoShorts.FilterError,
              "reverse_order expects true, got: #{inspect(value)}"
    end
  end
end
