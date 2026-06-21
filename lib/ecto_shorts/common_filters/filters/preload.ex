defmodule EctoShorts.CommonFilters.Preload do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:preload` structural filter for `EctoShorts.CommonFilters`.

  Adds Ecto preload instructions to the query. Accepts an association atom, a
  list of atoms, or a nested map/keyword list for deep preloads. When a named
  binding is active the preload is scoped to that binding. Used via params, not
  called directly:

      EctoShorts.Actions.all(Post, %{preload: :comments})
      EctoShorts.Actions.all(Post, %{preload: [:comments, :tags]})
      EctoShorts.Actions.all(Post, %{preload: %{comments: :author}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.{LogUtils, QueryBinding}
  alias EctoShorts.CommonFilters.Normalizer

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Preload"

  def build_query(:preload, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:preload, _source, query, selected_binding, params, _opts) do
    case selected_binding do
      {:as, nil} -> build_preload(query, params)
      _ -> apply_preload(query, selected_binding, params)
    end
  end

  defp apply_preload(query, selected_binding, params)
       when is_map(params) and not is_struct(params) do
    apply_preload(query, selected_binding, Map.to_list(params))
  end

  defp apply_preload(query, selected_binding, params) when is_list(params) do
    Enum.reduce(params, query, fn
      {assoc_key, nested}, query_acc ->
        build_preload(query_acc, selected_binding, assoc_key, nested)

      assoc_key, query_acc ->
        build_preload(query_acc, selected_binding, assoc_key, nil)
    end)
  end

  defp apply_preload(query, _selected_binding, value)
       when not is_atom(value) do
    LogUtils.warning(@logger_prefix, "Expected :preload to be an atom, list, or map, got: #{inspect(value)}")
    query
  end

  defp apply_preload(query, selected_binding, assoc_key) do
    build_preload(query, selected_binding, assoc_key, nil)
  end

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp build_preload(query, unquote(quoted_binding_head), assoc_key, nil) do
      Query.preload(
        query,
        [unquote_splicing(quoted_binding_body)],
        [{^assoc_key, unquote(target_binding_var)}]
      )
    end

    defp build_preload(query, unquote(quoted_binding_head), assoc_key, nested) do
      prepared_nested =
        case Normalizer.normalize_preload(nested) do
          [{key, value}] -> {key, value}
          other -> other
        end

      Query.preload(
        query,
        [unquote_splicing(quoted_binding_body)],
        [{^assoc_key, {unquote(target_binding_var), ^prepared_nested}}]
      )
    end
  end

  defp build_preload(query, value) when not is_atom(value) and not is_map(value) and not is_list(value) do
    LogUtils.warning(@logger_prefix, "Expected :preload to be an atom, list, or map, got: #{inspect(value)}")
    query
  end

  defp build_preload(query, value) do
    preloads = Normalizer.normalize_preload(value)
    Query.preload(query, ^preloads)
  end

end
