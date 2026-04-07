defmodule EctoShorts.CommonFilters.Join do
  @moduledoc since: "3.0.0"
  @moduledoc false

  compiled_hints =
    case Application.compile_env(:ecto_shorts, :hints) do
      nil ->
        []

      hints when is_list(hints) ->
        hints

      mod when is_atom(mod) ->
        mod.hints()

      term ->
        raise ArgumentError, "Expected :hints to be a list or module, got: #{inspect(term)}"
    end

  @hints compiled_hints

  alias EctoShorts.DynamicBuilders
  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.QueryBinding
  alias EctoShorts.Config
  alias EctoShorts.Adapter.QueryProvider

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Join"

  @join_types [:association, :schema, :table, :query, :subquery, :fragment]

  @doc false
  def hints, do: @hints

  def build_query(:join, schema_source, query, selected_binding, params, opts) do
    reduce_params(params, schema_source, query, selected_binding, opts)
  end

  defp reduce_params(entries, schema_source, query, selected_binding, opts)
       when is_list(entries) do
    apply_join_op(schema_source, query, selected_binding, entries, opts)
  end

  defp apply_join_op(schema_source, query, selected_binding, {key, join_options}, opts) do
    if key in @join_types do
      reduce_join(schema_source, query, selected_binding, {key, join_options}, opts)
    else
      associations = CommonSchema.get_schema_reflection(schema_source, :associations) || []

      if key in associations do
        join_expr = {:association, Keyword.put(join_options, :source, key)}

        reduce_join(schema_source, query, selected_binding, join_expr, opts)
      else
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected join type to be one of #{inspect(@join_types)}, got: #{inspect(key)}"
        )

        query
      end
    end
  end

  defp apply_join_op(schema_source, query, selected_binding, nested, opts) do
    if is_list(nested) do
      if Keyword.keyword?(nested) and Keyword.has_key?(nested, :source) do
        {type, options} = Keyword.pop(nested, :type, :association)
        apply_join_op(schema_source, query, selected_binding, {type, options}, opts)
      else
        Enum.reduce(nested, query, fn entry, inner_acc ->
          apply_join_op(schema_source, inner_acc, selected_binding, entry, opts)
        end)
      end
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Expected :join params to be a map or keyword list, got: #{inspect(nested)}"
      )

      query
    end
  end

  defp reduce_join(schema_source, query, selected_binding, {join_type, join_options}, opts) do
    {op_source, join_options} = Keyword.pop(join_options, :source)

    if op_source !== nil do
      apply_join_expr(
        schema_source,
        query,
        selected_binding,
        {join_type, op_source, join_options},
        opts
      )
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Expected join options to have a :source key, got: #{inspect(join_options)}"
      )

      query
    end
  end

  defp resolve_expr_source(selected_binding, source_key, source_params, opts) do
    case opts
         |> query_provider()
         |> QueryProvider.query_expression(
           selected_binding,
           source_key,
           source_params,
           opts
         ) do
      nil ->
        :error

      {:ok, source} ->
        {:ok, source}

      {:error, reason} ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Join source callback returned error for key #{inspect(source_key)}: #{inspect(reason)}"
        )

        :error

      other ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected join source callback to return {:ok, source} | {:error, reason} | nil, got: #{inspect(other)}"
        )

        :error
    end
  end

  defp resolve_join_operation(
         schema_source,
         query,
         selected_binding,
         {join_type, op_source, join_options},
         opts
       ) do
    with {:ok, on_value} <-
           reduce_on_params(schema_source, query, selected_binding, join_options[:on], opts),
         {:ok, source} <-
           resolve_join_source(schema_source, selected_binding, join_type, op_source, opts) do
      {:ok,
       %{
         qualifier: join_options[:qualifier] || :inner,
         prefix: join_options[:prefix],
         as: join_options[:as],
         hints: join_options[:hints],
         on: on_value,
         source: source
       }}
    else
      :error ->
        :error
    end
  end

  defp resolve_join_source(_schema_source, _selected_binding, :association, assoc_key, _opts) do
    {:ok, {:association, assoc_key}}
  end

  defp resolve_join_source(_schema_source, _selected_binding, :schema, target_schema, _opts) do
    source =
      case target_schema do
        {table, schema}
        when is_binary(table) and table !== "" and is_atom(schema) and not is_nil(schema) ->
          {table, schema}

        schema when is_atom(schema) and not is_nil(schema) ->
          schema

        _ ->
          raise ArgumentError,
                "Expected target schema to be an atom or a tuple of {table, schema}, got: #{inspect(target_schema)}"
      end

    {:ok, {:source, source}}
  end

  defp resolve_join_source(_schema_source, _selected_binding, :table, table_name, _opts) do
    {:ok, {:source, table_name}}
  end

  defp resolve_join_source(_schema_source, _selected_binding, :query, source_query, _opts) do
    unless is_struct(source_query, Ecto.Query) do
      raise ArgumentError, "Expected source query to be a struct, got: #{inspect(source_query)}"
    end

    {:ok, {:source, source_query}}
  end

  defp resolve_join_source(schema_source, _selected_binding, :subquery, params, opts) do
    subquery_source =
      if is_struct(params, Ecto.Query) or is_struct(params, Ecto.SubQuery) do
        params
      else
        {from_source, filter_params} = Keyword.pop(params, :from, schema_source)
        CommonFilters.convert_params_to_filter(from_source, filter_params, opts)
      end

    {:ok, {:subquery, subquery_source}}
  end

  defp resolve_join_source(_schema_source, selected_binding, :fragment, params, opts) do
    source_name = params[:name]
    source_values = params[:values]

    if is_nil(source_name) do
      raise ArgumentError, "Join source name is required, got: #{inspect(params)}"
    end

    if is_nil(source_values) do
      raise ArgumentError, "Join source values are required, got: #{inspect(params)}"
    end

    case resolve_expr_source(selected_binding, source_name, source_values, opts) do
      {:ok, source} ->
        {:ok, {:source, source}}

      :error ->
        :error
    end
  end

  defp reduce_on_params(schema_source, query, selected_binding, on_param, opts) do
    case on_param do
      on_param when on_param in [true, nil] ->
        {:ok, true}

      map when is_map(map) and not is_struct(map) ->
        case build_on_dynamic(schema_source, query, selected_binding, map, opts) do
          nil -> :error
          dyn -> {:ok, dyn}
        end

      list when is_list(list) ->
        if Keyword.keyword?(list) do
          case build_on_dynamic(schema_source, query, selected_binding, list, opts) do
            nil -> :error
            dyn -> {:ok, dyn}
          end
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Expected :on to be a keyword list, map, or true, got: #{inspect(list)}"
          )

          :error
        end

      %Ecto.Query.DynamicExpr{} = dyn ->
        {:ok, dyn}

      term ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Expected :on to be a keyword list, map, or true, got: #{inspect(term)}"
        )

        :error
    end
  end

  defp build_on_dynamic(schema_source, query, selected_binding, entries, opts) do
    effective_source = resolve_source(schema_source, query, selected_binding)

    Enum.reduce(entries, nil, fn {key, value}, acc ->
      dyn = DynamicBuilders.build_dynamic(effective_source, selected_binding, {key, value}, opts)
      merge_dynamic(acc, :and, dyn)
    end)
  end

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end

  defp resolve_source(source, _query, _selected_binding), do: source

  defp merge_dynamic(nil, _, b), do: b
  defp merge_dynamic(a, _, nil), do: a
  defp merge_dynamic(a, :and, b), do: Query.dynamic(^a and ^b)

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp apply_join_expr(
           schema_source,
           query,
           unquote(quoted_binding_head) = selected_binding,
           join_expr,
           opts
         ) do
      case resolve_join_operation(schema_source, query, selected_binding, join_expr, opts) do
        {:ok, join_op} ->
          join_expr(
            query,
            selected_binding,
            join_op.qualifier,
            join_op.source,
            join_op.as,
            join_op.on,
            join_op.prefix,
            join_op.hints
          )

        :error ->
          query
      end
    end

    for {hint_key, hint_value} <- @hints do
      defp join_expr(
             query,
             unquote(quoted_binding_head) = _selected_binding,
             qualifier,
             {:association, assoc_key},
             as,
             on,
             prefix,
             unquote(hint_key)
           ) do
        Query.join(
          query,
          qualifier,
          [unquote_splicing(quoted_binding_body)],
          joined in assoc(unquote(target_binding_var), ^assoc_key),
          as: ^as,
          on: ^on,
          prefix: ^prefix,
          hints: unquote(hint_value)
        )
      end

      defp join_expr(
             query,
             unquote(quoted_binding_head) = _selected_binding,
             qualifier,
             {:source, source},
             as,
             on,
             prefix,
             unquote(hint_key)
           ) do
        Query.join(
          query,
          qualifier,
          [unquote_splicing(quoted_binding_body)],
          joined in ^source,
          as: ^as,
          on: ^on,
          prefix: ^prefix,
          hints: unquote(hint_value)
        )
      end

      defp join_expr(
             query,
             unquote(quoted_binding_head) = _selected_binding,
             qualifier,
             {:subquery, subquery_source},
             as,
             on,
             prefix,
             unquote(hint_key)
           ) do
        Query.join(
          query,
          qualifier,
          [unquote_splicing(quoted_binding_body)],
          joined in subquery(subquery_source),
          as: ^as,
          on: ^on,
          prefix: ^prefix,
          hints: unquote(hint_value)
        )
      end
    end

    defp join_expr(
           query,
           unquote(quoted_binding_head) = _selected_binding,
           qualifier,
           {:association, assoc_key},
           as,
           on,
           prefix,
           _hints
         ) do
      Query.join(
        query,
        qualifier,
        [unquote_splicing(quoted_binding_body)],
        joined in assoc(unquote(target_binding_var), ^assoc_key),
        as: ^as,
        on: ^on,
        prefix: ^prefix
      )
    end

    defp join_expr(
           query,
           unquote(quoted_binding_head) = _selected_binding,
           qualifier,
           {:source, source},
           as,
           on,
           prefix,
           _hints
         ) do
      Query.join(
        query,
        qualifier,
        [unquote_splicing(quoted_binding_body)],
        joined in ^source,
        as: ^as,
        on: ^on,
        prefix: ^prefix
      )
    end

    defp join_expr(
           query,
           unquote(quoted_binding_head) = _selected_binding,
           qualifier,
           {:subquery, subquery_source},
           as,
           on,
           prefix,
           _hints
         ) do
      Query.join(
        query,
        qualifier,
        [unquote_splicing(quoted_binding_body)],
        joined in subquery(subquery_source),
        as: ^as,
        on: ^on,
        prefix: ^prefix
      )
    end
  end

  defp query_provider(opts) do
    opts[:query_provider_module] || Config.query_provider_module()
  end
end
