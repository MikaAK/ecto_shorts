defmodule EctoShorts.CommonFilters.Normalizer do
  @moduledoc false

  alias EctoShorts.CommonSchema
  alias EctoShorts.LogUtils

  @logger_prefix "EctoShorts.CommonFilters.Normalizer"

  @structural_keys %{
    "all" => :all, "and" => :and, "any" => :any, "as" => :as, "at" => :at,
    "distinct" => :distinct, "except" => :except, "except_all" => :except_all,
    "exclude" => :exclude, "first" => :first, "group_by" => :group_by,
    "having" => :having, "intersect" => :intersect, "intersect_all" => :intersect_all,
    "join" => :join, "last" => :last, "limit" => :limit, "lock" => :lock,
    "offset" => :offset, "or" => :or, "or_having" => :or_having, "or_where" => :or_where,
    "page" => :page, "prepend_order_by" => :prepend_order_by, "preload" => :preload,
    "put_query_prefix" => :put_query_prefix, "recursive_ctes" => :recursive_ctes,
    "reverse_order" => :reverse_order, "select" => :select, "select_merge" => :select_merge,
    "subquery" => :subquery, "union" => :union, "union_all" => :union_all,
    "order_by" => :order_by, "update" => :update, "where" => :where, "windows" => :windows,
    "with_cte" => :with_cte, "with_named_binding" => :with_named_binding,
    "with_ties" => :with_ties
  }

  @direction_map %{
    "asc" => :asc, "asc_nulls_last" => :asc_nulls_last, "asc_nulls_first" => :asc_nulls_first,
    "desc" => :desc, "desc_nulls_last" => :desc_nulls_last, "desc_nulls_first" => :desc_nulls_first
  }

  @join_type_map %{
    "association" => :association, "schema" => :schema, "table" => :table,
    "query" => :query, "subquery" => :subquery, "fragment" => :fragment
  }

  @last_keys %{"sort_by" => :sort_by, "limit" => :limit}

  @at_aliases %{"first" => :first, "last" => :last}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Normalize string keys in params to atoms. Returns params unchanged if not a map or list."
  def normalize(params, source) when is_map(params) and not is_struct(params) do
    Map.new(params, fn {key, value} ->
      k = normalize_key(key, source)
      {k, normalize_value(k, value, source)}
    end)
  end

  def normalize(params, source) when is_list(params) do
    Enum.map(params, fn
      {key, value} ->
        k = normalize_key(key, source)
        {k, normalize_value(k, value, source)}

      other ->
        other
    end)
  end

  def normalize(other, _source), do: other

  @doc "Normalize a preload value — converts maps to keyword lists and wraps atoms."
  def normalize_preload(params) when is_map(params) and not is_struct(params) do
    params
    |> Map.to_list()
    |> normalize_preload()
  end

  def normalize_preload(params) when is_list(params) do
    if Keyword.keyword?(params) do
      Enum.map(params, fn {key, value} ->
        {key, normalize_preload(value)}
      end)
    else
      params
    end
  end

  def normalize_preload(nil), do: []
  def normalize_preload(name) when is_atom(name), do: [name]
  def normalize_preload(term), do: term

  # ---------------------------------------------------------------------------
  # Key normalization
  # ---------------------------------------------------------------------------

  defp normalize_key(key, _source) when is_atom(key), do: key

  defp normalize_key(key, source) when is_binary(key) do
    case Map.fetch(@structural_keys, key) do
      {:ok, atom} ->
        atom

      :error ->
        normalize_schema_identifier(key, assoc_atoms_for(source))
    end
  end

  # normalize_key/1 — for value normalizers where source isn't relevant
  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key) do
    case Map.fetch(@structural_keys, key) do
      {:ok, atom} -> atom
      :error -> normalize_user_identifier(key)
    end
  end
  defp normalize_key(key), do: key

  # ---------------------------------------------------------------------------
  # Value normalization — dispatched by structural key
  # ---------------------------------------------------------------------------

  defp normalize_value(key, value, source) when key in [:and, :or, :all, :any] do
    normalize(value, source)
  end

  defp normalize_value(:as, value, source) when is_map(value) or is_list(value) do
    normalize_kv_container(value, &normalize_user_identifier/1, fn _k, v -> normalize(v, source) end)
  end

  defp normalize_value(:at, value, source) when is_map(value) or is_list(value) do
    normalize_kv_container(value, &normalize_binding_position/1, fn _k, v -> normalize(v, source) end)
  end

  defp normalize_value(key, value, source) when key in [:where, :or_where, :having, :or_having] do
    normalize_predicate_container(value, source)
  end

  defp normalize_value(:join, value, source), do: normalize_join(value, source)

  defp normalize_value(key, value, _source) when key in [:order_by, :prepend_order_by] do
    normalize_order(value)
  end

  defp normalize_value(:group_by, value, source), do: normalize_fields(value, source)

  defp normalize_value(:distinct, value, _source), do: normalize_order(value)

  defp normalize_value(key, value, _source) when key in [:select, :select_merge], do: value

  defp normalize_value(:preload, value, _source), do: normalize_preload(value)

  defp normalize_value(:page, value, _source), do: normalize_page(value)

  defp normalize_value(:with_cte, value, source), do: normalize_with_cte(value, source)

  defp normalize_value(:windows, value, _source), do: normalize_windows(value)

  defp normalize_value(:with_named_binding, value, _source) do
    normalize_kv_container(value, &normalize_user_identifier/1, fn _k, v -> v end)
  end

  defp normalize_value(:exclude, value, _source) when is_list(value) do
    Enum.map(value, &normalize_key/1)
  end

  defp normalize_value(:exclude, value, _source), do: normalize_key(value)

  defp normalize_value(:last, value, _source) when is_map(value) or is_list(value) do
    normalize_kv_container(
      value,
      fn k -> Map.get(@last_keys, to_string(k), normalize_key(k)) end,
      fn _k, v -> v end
    )
  end

  defp normalize_value(:last, value, _source), do: value

  defp normalize_value(:subquery, value, source)
       when is_map(value) and not is_struct(value) do
    Map.new(value, fn
      {"select", fields} -> {:select, normalize_subquery_select_fields(fields, source)}
      {:select, fields}  -> {:select, normalize_subquery_select_fields(fields, source)}
      {k, v}             -> {normalize_key(k), v}
    end)
  end

  defp normalize_value(key, value, source) when is_atom(key) do
    cond do
      assoc_key?(source, key) and (is_map(value) and not is_struct(value) or is_list(value)) ->
        normalize(value, get_assoc_source(source, key))

      is_map(value) and not is_struct(value) or is_list(value) ->
        normalize_predicate_container(value, source)

      true ->
        value
    end
  end

  defp normalize_value(_key, value, _source), do: value

  # ---------------------------------------------------------------------------
  # Predicate container — normalizes field names inside :where/:having values
  # ---------------------------------------------------------------------------

  defp normalize_predicate_container(value, source) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} ->
      norm_k = normalize_schema_identifier(k, field_atoms_for(source))
      {norm_k, normalize_predicate_value(norm_k, v, source)}
    end)
  end

  defp normalize_predicate_container(value, source) when is_list(value) do
    Enum.map(value, fn
      {k, v} ->
        norm_k = normalize_schema_identifier(k, field_atoms_for(source))
        {norm_k, normalize_predicate_value(norm_k, v, source)}

      map when is_map(map) and not is_struct(map) ->
        normalize_predicate_container(map, source)

      other ->
        other
    end)
  end

  defp normalize_predicate_container(other, _source), do: other

  defp normalize_predicate_value(:field, name, source) when is_binary(name) do
    normalize_schema_identifier(name, field_atoms_for(source))
  end

  defp normalize_predicate_value(_key, value, source) when is_map(value) or is_list(value) do
    normalize_predicate_container(value, source)
  end

  defp normalize_predicate_value(_key, value, _source), do: value

  # ---------------------------------------------------------------------------
  # Join normalization
  # ---------------------------------------------------------------------------

  @join_qualifier_map %{
    "inner" => :inner, "left" => :left, "right" => :right, "full" => :full, "cross" => :cross
  }

  defp normalize_join(entries, source) when is_list(entries) do
    Enum.map(entries, fn
      {key, opts} ->
        norm_key = Map.get(@join_type_map, to_string(key), key)
        {norm_key, normalize_join_opts(norm_key, opts, source)}

      entry when is_map(entry) and not is_struct(entry) ->
        case Map.to_list(entry) do
          [{key, opts}] ->
            norm_key = Map.get(@join_type_map, to_string(key), key)
            {norm_key, normalize_join_opts(norm_key, opts, source)}
          _ ->
            entry
        end

      other ->
        other
    end)
  end

  defp normalize_join(other, _source), do: other

  defp normalize_join_opts(_join_type, opts, _source) when is_list(opts) or is_map(opts) do
    normalize_kv_container(opts, fn k ->
      case to_string(k) do
        "qualifier" -> :qualifier
        "source"    -> :source
        "as"        -> :as
        "on"        -> :on
        "prefix"    -> :prefix
        "hints"     -> :hints
        _           -> normalize_key(k)
      end
    end, fn
      :qualifier, v -> Map.get(@join_qualifier_map, to_string(v), v)
      _k, v         -> v
    end)
  end

  defp normalize_join_opts(_join_type, opts, _source), do: opts

  # ---------------------------------------------------------------------------
  # Order normalization
  # ---------------------------------------------------------------------------

  defp normalize_order(entries) when is_list(entries) do
    Enum.map(entries, fn
      {k, v} ->
        norm_k = Map.get(@direction_map, to_string(k), normalize_key(k))
        {norm_k, v}

      entry when is_map(entry) and not is_struct(entry) ->
        case Map.to_list(entry) do
          [{k, v}] ->
            norm_k = Map.get(@direction_map, to_string(k), normalize_key(k))
            {norm_k, v}
          _ ->
            entry
        end

      other ->
        other
    end)
  end

  defp normalize_order(other), do: other

  # ---------------------------------------------------------------------------
  # Field list normalization (group_by)
  # ---------------------------------------------------------------------------

  defp normalize_fields(entries, source) when is_list(entries) do
    Enum.map(entries, fn
      f when is_atom(f) -> f
      f when is_binary(f) -> normalize_schema_identifier(f, field_atoms_for(source))
      other -> other
    end)
  end

  defp normalize_fields(other, _source), do: other

  # ---------------------------------------------------------------------------
  # with_cte normalization — CTE names are user-defined identifiers
  # ---------------------------------------------------------------------------

  defp normalize_with_cte(value, source) when is_map(value) or is_list(value) do
    normalize_kv_container(
      value,
      &normalize_user_identifier/1,
      fn _cte_name, def_value -> normalize_cte_definition(def_value, source) end
    )
  end

  defp normalize_with_cte(other, _source), do: other

  defp normalize_cte_definition(value, source) when is_map(value) or is_list(value) do
    normalize(value, source)
  end

  defp normalize_cte_definition(other, _source), do: other

  # ---------------------------------------------------------------------------
  # windows normalization
  # ---------------------------------------------------------------------------

  defp normalize_windows(value) when is_map(value) or is_list(value) do
    normalize_kv_container(
      value,
      &normalize_user_identifier/1,
      fn _k, v -> v end
    )
  end

  defp normalize_windows(other), do: other

  # ---------------------------------------------------------------------------
  # page normalization
  # ---------------------------------------------------------------------------

  defp normalize_page(value) when is_map(value) or is_list(value) do
    normalize_kv_container(value, fn k ->
      case to_string(k) do
        "page_number" -> :page_number
        "page_size"   -> :page_size
        _             -> normalize_key(k)
      end
    end, fn _k, v -> v end)
  end

  defp normalize_page(other), do: other

  # ---------------------------------------------------------------------------
  # subquery select field normalization
  # ---------------------------------------------------------------------------

  defp normalize_subquery_select_fields(fields, source) when is_binary(fields) do
    normalize_schema_identifier(fields, field_atoms_for(source))
  end

  defp normalize_subquery_select_fields(fields, _source), do: fields

  # ---------------------------------------------------------------------------
  # Binding position normalization (:at key)
  # ---------------------------------------------------------------------------

  defp normalize_binding_position(key) when is_atom(key), do: key
  defp normalize_binding_position(key) when is_binary(key) do
    case Map.fetch(@at_aliases, key) do
      {:ok, atom} -> atom
      :error ->
        case Integer.parse(key) do
          {n, ""} -> n
          _ -> normalize_user_identifier(key)
        end
    end
  end
  defp normalize_binding_position(key), do: key

  # ---------------------------------------------------------------------------
  # Stratified identifier helpers
  # ---------------------------------------------------------------------------

  # normalize_schema_identifier — validates against known schema atoms via reflection.
  # Never creates new atoms. Passes string through with warning on failure.
  defp normalize_schema_identifier(key, _known_atoms) when is_atom(key), do: key

  defp normalize_schema_identifier(key, known_atoms) when is_binary(key) do
    case Enum.find(known_atoms, fn a -> Atom.to_string(a) == key end) do
      nil ->
        LogUtils.warning(
          @logger_prefix,
          "Unknown schema identifier: #{inspect(key)}, passing through as string"
        )
        key

      atom ->
        atom
    end
  end

  # normalize_user_identifier — for user-defined identifiers (CTE names, binding names, window names).
  # Uses String.to_existing_atom/1 with rescue. Passes string through with warning on failure.
  defp normalize_user_identifier(key) when is_atom(key), do: key

  defp normalize_user_identifier(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError ->
      LogUtils.warning(
        @logger_prefix,
        "Could not normalize identifier #{inspect(key)} to atom — atom does not exist in VM. Passing through as string."
      )
      key
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp normalize_kv_container(value, key_fn, value_fn) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} ->
      norm_k = key_fn.(k)
      {norm_k, value_fn.(norm_k, v)}
    end)
  end

  defp normalize_kv_container(value, key_fn, value_fn) when is_list(value) do
    Enum.map(value, fn
      {k, v} ->
        norm_k = key_fn.(k)
        {norm_k, value_fn.(norm_k, v)}

      other ->
        other
    end)
  end

  defp normalize_kv_container(value, _key_fn, _value_fn), do: value

  defp assoc_atoms_for(nil), do: []
  defp assoc_atoms_for(source) do
    CommonSchema.get_schema_reflection(source, :associations) || []
  end

  defp field_atoms_for(nil), do: []
  defp field_atoms_for(source) do
    CommonSchema.get_schema_reflection(source, :fields) || []
  end

  defp assoc_key?(source, key) do
    key in assoc_atoms_for(source)
  end

  defp get_assoc_source(source, assoc_key) do
    case CommonSchema.get_schema_reflection(source, :associations) do
      assocs when is_list(assocs) ->
        schema = CommonSchema.get_schema(source)
        if schema && function_exported?(schema, :__schema__, 2) do
          schema.__schema__(:association, assoc_key)
          |> case do
            %{related: related} -> related
            _ -> nil
          end
        else
          nil
        end

      _ ->
        nil
    end
  end
end
