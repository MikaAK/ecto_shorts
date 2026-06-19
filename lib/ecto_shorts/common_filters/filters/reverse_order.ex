defmodule EctoShorts.CommonFilters.ReverseOrder do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.ReverseOrder"

  def build_query(:reverse_order, _source, query, _selected_binding, value, _opts) do
    case value do
      nil ->
        Query.reverse_order(query)

      true ->
        Query.reverse_order(query)

      _ ->
        EctoShorts.LogUtils.warning(
          @logger_prefix,
          "Expected :reverse_order value to be true, got: #{inspect(value)}"
        )

        query
    end
  end
end
