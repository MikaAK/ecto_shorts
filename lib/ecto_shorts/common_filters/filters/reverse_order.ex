defmodule EctoShorts.CommonFilters.ReverseOrder do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:reverse_order` structural filter for `EctoShorts.CommonFilters`.

  Reverses the current `ORDER BY` directions on the query using
  `Ecto.Query.reverse_order/1`. Accepts `true` or `nil` to apply the reversal;
  `false` leaves the query unchanged. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{order_by: :inserted_at, reverse_order: true})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

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
