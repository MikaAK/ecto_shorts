defmodule EctoShorts.CommonFilters.ReverseOrder do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.LogUtils
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.ReverseOrder"

  def build_query(:reverse_order, _source, query, _selected_binding, value, _opts) do
    case value do
      nil ->
        Query.reverse_order(query)

      true ->
        Query.reverse_order(query)

      false ->
        query

      _ ->
        LogUtils.warning(
          @logger_prefix,
          "Expected :reverse_order to be true or false, got: #{inspect(value)}"
        )

        query
    end
  end
end
