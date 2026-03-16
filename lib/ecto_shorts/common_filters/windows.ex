defmodule EctoShorts.CommonFilters.Windows do
  @moduledoc false

  alias EctoShorts.QueryBinding
  alias EctoShorts.Logger

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Windows"

  @payload_window_keys [:window, :partition_by, :order_by, :frame]
  @window_keys [:partition_by, :order_by, :frame]

  def build_query(:windows, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:windows, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:windows, _source, query, selected_binding, params, _opts) do
    reduce_params(query, selected_binding, params)
  end

  defp reduce_params(query, selected_binding, params) when is_list(params) do
    case resolve_window_entries(params) do
      {:ok, resolved_entries} ->
        Enum.reduce(resolved_entries, query, fn {window_name, window_definition}, query_acc ->
          apply_window(query_acc, selected_binding, window_name, window_definition)
        end)

      :error ->
        query
    end
  end

  defp reduce_params(query, _selected_binding, value) do
    Logger.warning(
      @logger_prefix,
      "Expected :windows params to be a map or keyword list, got: #{inspect(value)}"
    )

    query
  end

  defp resolve_window_entries(params) do
    with {:ok, ordered_entries} <- validate_window_entries(params),
         {:ok, resolved_map} <- resolve_window_definitions(ordered_entries) do
      {:ok,
       Enum.map(ordered_entries, fn {window_name, _} ->
         {window_name, Map.fetch!(resolved_map, window_name)}
       end)}
    end
  end

  defp validate_window_entries(params) do
    Enum.reduce_while(params, {:ok, []}, fn
      {window_name, window_definition}, {:ok, entries} ->
        cond do
          not is_atom(window_name) ->
            Logger.warning(
              @logger_prefix,
              "Expected window name to be an atom, got: #{inspect(window_name)}"
            )

            {:halt, :error}

          not Keyword.keyword?(window_definition) ->
            Logger.warning(
              @logger_prefix,
              "Expected window definition for #{inspect(window_name)} to be a map or keyword list, got: #{inspect(window_definition)}"
            )

            {:halt, :error}

          true ->
            {:cont,
             {:ok,
              entries ++ [{window_name, Keyword.take(window_definition, @payload_window_keys)}]}}
        end

      other, _acc ->
        Logger.warning(
          @logger_prefix,
          "Expected :windows params to be a map or keyword list, got: #{inspect(other)}"
        )

        {:halt, :error}
    end)
  end

  defp resolve_window_definitions(ordered_entries) do
    definitions_by_name = Map.new(ordered_entries)

    Enum.reduce_while(ordered_entries, {:ok, %{}}, fn {window_name, _window_definition},
                                                      {:ok, resolved_map} ->
      case resolve_window_definition(window_name, definitions_by_name, resolved_map, []) do
        {:ok, _resolved_definition, resolved_map} ->
          {:cont, {:ok, resolved_map}}

        :error ->
          {:halt, :error}
      end
    end)
  end

  defp resolve_window_definition(window_name, _definitions_by_name, resolved_map, _path)
       when is_map_key(resolved_map, window_name) do
    {:ok, Map.fetch!(resolved_map, window_name), resolved_map}
  end

  defp resolve_window_definition(window_name, definitions_by_name, resolved_map, path) do
    if window_name in path do
      Logger.warning(
        @logger_prefix,
        "Detected cyclic :windows reference involving #{inspect(window_name)}"
      )

      :error
    else
      definition = Map.fetch!(definitions_by_name, window_name)

      case definition[:window] do
        nil ->
          resolved_definition = Keyword.take(definition, @window_keys)
          {:ok, resolved_definition, Map.put(resolved_map, window_name, resolved_definition)}

        referenced_window when not is_atom(referenced_window) ->
          Logger.warning(
            @logger_prefix,
            "Expected :window for #{inspect(window_name)} to be an atom, got: #{inspect(referenced_window)}"
          )

          :error

        referenced_window ->
          if is_nil(definitions_by_name[referenced_window]) do
            Logger.warning(
              @logger_prefix,
              "Expected referenced window #{inspect(referenced_window)} for #{inspect(window_name)} to exist"
            )

            :error
          else
            case resolve_window_definition(referenced_window, definitions_by_name, resolved_map, [
                   window_name | path
                 ]) do
              {:ok, base_definition, resolved_map} ->
                local_definition = Keyword.take(definition, @window_keys)
                resolved_definition = Keyword.merge(base_definition, local_definition)

                {:ok, resolved_definition,
                 Map.put(resolved_map, window_name, resolved_definition)}

              :error ->
                :error
            end
          end
      end
    end
  end

  defp apply_window(query, selected_binding, window_name, window_definition) do
    cond do
      not is_atom(window_name) ->
        Logger.warning(
          @logger_prefix,
          "Expected window name to be an atom, got: #{inspect(window_name)}"
        )

        query

      not Keyword.keyword?(window_definition) ->
        Logger.warning(
          @logger_prefix,
          "Expected window definition for #{inspect(window_name)} to be a map or keyword list, got: #{inspect(window_definition)}"
        )

        query

      true ->
        definition = Keyword.take(window_definition, @window_keys)
        partition_by = normalize_partition_by(definition[:partition_by] || [], selected_binding)
        order_by = normalize_order_by(definition[:order_by] || [], selected_binding)
        frame = definition[:frame]

        if is_nil(frame) or is_atom(frame) or is_struct(frame, Ecto.Query.DynamicExpr) do
          apply_window_definition(
            query,
            selected_binding,
            window_name,
            partition_by,
            order_by,
            frame
          )
        else
          Logger.warning(
            @logger_prefix,
            "Expected :frame for #{inspect(window_name)} to be an Ecto dynamic expression, got: #{inspect(frame)}"
          )

          query
        end
    end
  end

  defp normalize_partition_by(nil, _selected_binding), do: []

  defp normalize_partition_by(value, selected_binding) when is_atom(value) do
    [dynamic_field_expr(selected_binding, value)]
  end

  defp normalize_partition_by(values, selected_binding) when is_list(values) do
    if Keyword.keyword?(values) do
      values
    else
      Enum.map(values, fn
        value when is_atom(value) ->
          dynamic_field_expr(selected_binding, value)

        other ->
          other
      end)
    end
  end

  defp normalize_partition_by(value, _selected_binding), do: value

  defp normalize_order_by(nil, _selected_binding), do: []

  defp normalize_order_by(value, selected_binding) when is_atom(value) do
    [dynamic_field_expr(selected_binding, value)]
  end

  defp normalize_order_by({direction, field_name}, selected_binding) when is_atom(field_name) do
    [{direction, dynamic_field_expr(selected_binding, field_name)}]
  end

  defp normalize_order_by(values, selected_binding) when is_list(values) do
    if Keyword.keyword?(values) do
      Enum.map(values, fn
        {direction, field_name} when is_atom(field_name) ->
          {direction, dynamic_field_expr(selected_binding, field_name)}

        other ->
          other
      end)
    else
      Enum.map(values, fn
        value when is_atom(value) ->
          dynamic_field_expr(selected_binding, value)

        other ->
          other
      end)
    end
  end

  defp normalize_order_by(value, _selected_binding), do: value

  defp apply_window_definition(query, _selected_binding, window_name, partition_by, order_by, nil) do
    Query.windows(
      query,
      [{window_name, [partition_by: ^partition_by, order_by: ^order_by]}]
    )
  end

  defp apply_window_definition(
         query,
         _selected_binding,
         window_name,
         partition_by,
         order_by,
         frame
       ) do
    Query.windows(
      query,
      [{window_name, [partition_by: ^partition_by, order_by: ^order_by, frame: ^frame]}]
    )
  end

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp dynamic_field_expr(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end
end
