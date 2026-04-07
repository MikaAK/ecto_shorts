defmodule EctoShorts.CommonFilters.WithCte do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonFilters
  alias EctoShorts.Types

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.WithCte"
  @cte_operations [:all, :update_all, :delete_all]

  def build_query(:with_cte, source, query, _selected_binding, params, opts) do
    reduce_params(source, query, params, opts)
  end

  defp reduce_params(schema_source, query, params, opts)
       when (is_map(params) and not is_struct(params)) or is_list(params) do
    Enum.reduce(params, query, fn entry, query_acc ->
      reduce_entry(schema_source, query_acc, entry, opts)
    end)
  end

  defp reduce_params(_schema_source, query, value, _opts) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "Expected :with_cte params to be a map or keyword list, got: #{inspect(value)}"
    )

    query
  end

  defp reduce_entry(schema_source, query, {cte_name, cte_definition}, opts) do
    apply_params(schema_source, query, cte_name, cte_definition, opts)
  end

  defp reduce_entry(schema_source, query, entry, opts)
       when is_map(entry) and not is_struct(entry) do
    reduce_params(schema_source, query, entry, opts)
  end

  defp reduce_entry(_schema_source, query, other, _opts) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "Expected :with_cte params to be a map or keyword list, got: #{inspect(other)}"
    )

    query
  end

  defp apply_params(schema_source, query, cte_name, cte_definition, opts) do
    cte_definition =
      if is_map(cte_definition) and not is_struct(cte_definition) do
        Map.to_list(cte_definition)
      else
        cte_definition
      end

    with {:ok, normalized_name} <- normalize_cte_name(cte_name),
         {:ok, cte_query} <-
           build_cte_query(schema_source, normalized_name, cte_definition, opts),
         {:ok, materialized} <- fetch_materialized(normalized_name, cte_definition),
         {:ok, operation} <- fetch_operation(normalized_name, cte_definition) do
      with_cte_expr(query, normalized_name, cte_query, materialized, operation)
    else
      :error -> query
    end
  end

  defp normalize_cte_name(cte_name) when is_atom(cte_name), do: {:ok, Atom.to_string(cte_name)}
  defp normalize_cte_name(cte_name) when is_binary(cte_name), do: {:ok, cte_name}
  defp normalize_cte_name(_), do: :error

  defp build_cte_query(schema_source, cte_name, cte_definition, opts) do
    case Keyword.fetch(cte_definition, :as) do
      {:ok, %Ecto.Query{} = query} ->
        {:ok, query}

      {:ok, %Ecto.SubQuery{} = query} ->
        {:ok, query}

      {:ok, params} when is_map(params) and not is_struct(params) ->
        {from_source, filter_params} = Map.pop(params, :from, schema_source)
        {:ok, CommonFilters.convert_params_to_filter(from_source, filter_params, opts)}

      {:ok, params} when is_list(params) ->
        {from_source, filter_params} = Keyword.pop(params, :from, schema_source)
        {:ok, CommonFilters.convert_params_to_filter(from_source, filter_params, opts)}

      {:ok, term} ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected CTE :as query params for #{inspect(cte_name)} to be a query, subquery, or keyword/map payload, got: #{inspect(term)}"
        )

        :error

      :error ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected :with_cte params for #{inspect(cte_name)} to include an :as key"
        )

        :error
    end
  end

  defp fetch_materialized(cte_name, cte_definition) do
    case Keyword.fetch(cte_definition, :materialized) do
      {:ok, value} when is_boolean(value) ->
        {:ok, value}

      {:ok, value} ->
        case Types.cast(:boolean, value) do
          cast when is_boolean(cast) or is_nil(cast) ->
            {:ok, cast}

          other ->
            EctoShorts.Logger.warning(
              @logger_prefix,
              "Expected :materialized for #{inspect(cte_name)} to be a boolean, got: #{inspect(other)}"
            )

            :error
        end

      :error ->
        {:ok, nil}
    end
  end

  defp fetch_operation(cte_name, cte_definition) do
    case Keyword.fetch(cte_definition, :operation) do
      {:ok, operation} when operation in @cte_operations ->
        {:ok, operation}

      {:ok, operation} ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected :operation for #{inspect(cte_name)} to be one of #{inspect(@cte_operations)}, got: #{inspect(operation)}"
        )

        :error

      :error ->
        {:ok, nil}
    end
  end

  defp with_cte_expr(query, cte_name, cte_query, nil, nil) do
    Query.with_cte(query, ^cte_name, as: ^cte_query)
  end

  defp with_cte_expr(query, cte_name, cte_query, materialized, nil) do
    Query.with_cte(query, ^cte_name, as: ^cte_query, materialized: materialized)
  end

  defp with_cte_expr(query, cte_name, cte_query, nil, operation) do
    Query.with_cte(query, ^cte_name, as: ^cte_query, operation: operation)
  end

  defp with_cte_expr(query, cte_name, cte_query, materialized, operation) do
    Query.with_cte(
      query,
      ^cte_name,
      as: ^cte_query,
      materialized: materialized,
      operation: operation
    )
  end
end
