defmodule EctoShorts.CommonFilters.Windows do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:windows` structural filter for `EctoShorts.CommonFilters`.

  Defines named window specifications for SQL window functions. Accepts a map
  or keyword list of `{window_name, window_definition}` pairs where each
  definition may include `:partition_by`, `:order_by`, `:frame`, and `:window`
  (to inherit from another named window). Cyclic `:window` references are
  detected and warned. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{
        windows: [row_num: [partition_by: :author_id, order_by: :inserted_at]]
      })

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.LogUtils
  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Windows"

  def build_query(:windows, _source, query, selected_binding, params, _opts)
      when is_list(params) do
    definitions = Map.new(params)
    seen = MapSet.new()

    Enum.reduce(params, query, fn {window_name, _}, acc ->
      apply_window(
        acc,
        selected_binding,
        window_name,
        expand_window(window_name, definitions, seen)
      )
    end)
  end

  def build_query(:windows, source, query, selected_binding, params, opts)
      when is_map(params) and not is_struct(params) do
    build_query(:windows, source, query, selected_binding, Map.to_list(params), opts)
  end

  def build_query(:windows, _source, query, _selected_binding, value, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :windows params to be a map or keyword list, got: #{inspect(value)}"
    )

    query
  end

  defp expand_window(name, definitions, seen) do
    if MapSet.member?(seen, name) do
      LogUtils.warning(
        @logger_prefix,
        "Detected cyclic :windows reference involving #{inspect(name)}"
      )

      []
    else
      definition = definitions[name] || []

      base =
        case definition[:window] do
          nil -> []
          parent -> expand_window(parent, definitions, MapSet.put(seen, name))
        end

      Keyword.merge(base, Keyword.take(definition, [:partition_by, :order_by, :frame]))
    end
  end

  defp apply_window(query, selected_binding, window_name, window_definition) do
    partition_by =
      window_definition[:partition_by]
      |> List.wrap()
      |> Enum.map(&dynamic_field_expr(selected_binding, &1))

    order_by =
      window_definition[:order_by]
      |> List.wrap()
      |> Enum.map(fn
        {direction, field} -> {direction, dynamic_field_expr(selected_binding, field)}
        field -> dynamic_field_expr(selected_binding, field)
      end)

    frame = window_definition[:frame]

    if is_nil(frame) or is_atom(frame) or is_struct(frame, Ecto.Query.DynamicExpr) do
      if partition_by !== [] or order_by !== [] or not is_nil(frame) do
        window_expr(
          query,
          selected_binding,
          window_name,
          partition_by,
          order_by,
          frame
        )
      else
        query
      end
    else
      LogUtils.warning(
        @logger_prefix,
        "Expected :frame for #{inspect(window_name)} to be an Ecto dynamic expression, got: #{inspect(frame)}"
      )

      query
    end
  end

  defp window_expr(query, _selected_binding, window_name, partition_by, order_by, nil) do
    Query.windows(
      query,
      [{window_name, [partition_by: ^partition_by, order_by: ^order_by]}]
    )
  end

  defp window_expr(
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

  ## Generated Functions

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
