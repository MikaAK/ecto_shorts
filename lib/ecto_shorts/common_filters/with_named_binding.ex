defmodule EctoShorts.CommonFilters.WithNamedBinding do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonFilters

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.WithNamedBinding"

  def build_query(:with_named_binding, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:with_named_binding, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:with_named_binding, _source, query, _selected_binding, params, opts) do
    if Keyword.keyword?(params) do
      reduce_params(query, params, opts)
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Expected :with_named_binding params to be a map or keyword list, got: #{inspect(params)}"
      )

      query
    end
  end

  defp reduce_params(query, params, opts) do
    Enum.reduce(params, query, fn
      {key, value}, query_acc ->
        apply_params(query_acc, key, value, opts)

      other, query_acc ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected :with_named_binding params to be a map or keyword list, got: #{inspect(other)}"
        )

        query_acc
    end)
  end

  defp apply_params(query, key, params, opts) do
    cond do
      not is_atom(key) ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected :with_named_binding key to be an atom, got: #{inspect(key)}"
        )

        query

      Query.has_named_binding?(query, key) ->
        query

      true ->
        query_acc = CommonFilters.convert_params_to_filter(query, params, opts)

        if Query.has_named_binding?(query_acc, key) do
          query_acc
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Filters provided for :with_named_binding key #{inspect(key)} did not create a named binding"
          )

          query
        end
    end
  end
end
