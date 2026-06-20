defmodule EctoShorts.CommonFilters do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Converts public filter params into an `Ecto.Query`.

  This module is the public query language for EctoShorts. It accepts a source
  plus a map or keyword list of params, sorts the params into evaluation order,
  and routes each entry to the appropriate builder.

  `convert_params_to_filter/3` is the main caller-facing entry point.
  `build_query/6` is the narrower callback boundary used by custom query
  builders.

  `source` may be a schema module, an `{source, schema}` tuple, or a prebuilt
  `Ecto.Query`. Params may be a map or a keyword list. Use a keyword list when
  duplicate keys and evaluation order matter, for example with repeated
  `where:`, `or_where:`, `join:`, or `with_cte:` entries.

  ## Examples

      CommonFilters.convert_params_to_filter(Post, %{published: true}, [])
      CommonFilters.convert_params_to_filter(Post, [where: %{published: true}, or_where: %{title: "Draft"}], [])

  ## Binding selectors

  Two top-level shapes retarget subsequent filters to a specific binding:

  * `:as` selects a named binding
  * `:at` selects a positional binding

  `:at` is 1-based and also accepts `:first` and `:last` inside the `at:` map.

      %{as: %{author: %{select: :first_name}}}
      %{at: %{2 => %{select: :first_name}}}
      %{at: %{first: %{select: :title}}}

  These are first-class public shapes. They are not wrapped in a separate
  `:bind` key.

  ## Boolean and predicate groups

  The top-level boolean and predicate keys are transparent grouping operators:

  * `:where` and `:or_where` add explicit predicate clauses
  * `:and` expands its contents as `WHERE` predicates
  * `:or` expands its contents as `OR WHERE` predicates

  Supported value shapes include maps, keyword lists, and lists of maps or
  keyword lists.

  ## Evaluation order

  Keyword-list params are reordered before evaluation:

  1. `:where`
  2. all other filters
  3. `:or_where`
  4. terminal filters such as `:last` and `:subquery`

  This keeps ordinary predicates ahead of `OR WHERE` clauses.

  ## Supported filter families

  The live public language includes:

  * field equality and comparison operators
  * aggregate and arithmetic expressions
  * string matching, string transformations, and negation
  * date and datetime wrappers
  * joins and association shorthand
  * ordering, grouping, having, distinct, limits, offsets, first, and last
  * projection through `:select` and `:select_merge`
  * eager loading through `:preload`
  * query updates, exclusions, and query prefixes
  * subqueries, set operations, recursive CTEs, `with_cte`, windows, and
    `with_ties`
  * named-binding support through `:with_named_binding`

  ## Filter Keys

  Filter keys let you shape how a query behaves by defining things like filtering,
  joins, ordering, grouping, selection, and other query clauses.

  Keys not listed below, and not recognized as schema associations, are treated as
  direct field filters.

  ### Filtering and boolean logic

  - `:where` and `:or_where` are used to apply predicate-based filtering. Use them
    when you want to include only rows that match specific conditions.
  - `:and` and `:or` are used to group boolean expressions. Use them when you
    need to control how multiple filter conditions are combined.
  - `:all` is an alias for `:and` — all given conditions are ANDed together.
  - `:any` is an alias for `:or` — conditions are combined with OR.

  ### Bindings

  - `:as` and `:at` are used to define or reference bindings/selectors in a query.
    Use them when you need to name bindings explicitly or target a specific binding
    position.

  ### Joins

  - `:join` is used to join associations, schemas, tables, queries, subqueries, or
    fragments. Use it when the query needs data from another source in addition to
    the main one.

  ### Ordering

  - `:order_by` is used to define the result ordering. Use it when the order of
    returned rows matters.

  - `:prepend_order_by` is used to add a new ordering rule ahead of existing ones.
    Use it when you want to preserve the current sort logic but make a new rule
    take priority.

  - `:reverse_order` is used to invert the current ordering. Use it when you want
    the same sort criteria in the opposite direction.

  ### Grouping and aggregate filtering

  - `:group_by` is used to group rows before aggregation. Use it when you are
    calculating grouped values such as counts, sums, or averages.
  - `:having` and `:or_having` are used to filter grouped results after aggregation.
    Use them when the condition depends on aggregate output rather than individual
    rows.

  ### Uniqueness

  - `:distinct` is used to remove duplicate rows from the result set. Use it when you
    only want unique results.

  ### Cardinality and pagination

  - `:limit` is used to cap the number of rows returned. Use it when you only need a
    maximum number of results.
  - `:offset` is used to skip a number of rows before returning results. Use it when
    implementing pagination or moving through a result set.
  - `:first` and `:last` are used to retrieve the first or last result or set of
    results. Use them when you need boundary results based on the current ordering.

  ### Projection

  - `:select` is used to control which fields are returned. Use it when you do not
    want the full row and only need specific values.
  - `:select_merge` is used to add fields into an existing selection. Use it when
    you want to extend a previous `:select` without replacing it.

  ### Preloading

  - `:preload` is used to eager load associations. Use it when related data will be
    needed and you want to avoid additional follow-up queries.

  ### Nested queries

  - `:subquery` is used to embed one query inside another. Use it when part of the
    query depends on the results of another query.

  ### Locking

  - `:lock` is used to apply locking behavior to the query. Use it when you need to
    coordinate concurrent access to rows, such as inside transactional update flows.

  ### Clause removal

  - `:exclude` is used to remove a clause from an existing query. Use it when you
    want to reuse a query while stripping out a specific part.

  ### Bulk updates

  - `:update` is used to define `update_all` expressions. Use it when you want to
    update records directly in the database without loading them first.

  ### Query prefixing

  - `:put_query_prefix` is used to set the query prefix. Use it when the query must
    target a specific schema, namespace, or database prefix.

  ### Common table expressions

  - `:recursive_ctes` and `:with_cte` are used to define common table expressions.
    Use them when you want to structure a complex query more clearly or need recursive
    query behavior.

  ### Windowing

  - `:windows` and `:with_ties` are used for windowing-related behavior. Use them when
    working with window functions or when you want limit-like behavior that preserves
    tied rows.

  ### Named bindings

  - `:with_named_binding` is used to support named bindings. Use it when you want
    more explicit and maintainable references to joined sources.

  ### Set composition

  - `:union` and `:union_all` are used to combine result sets from multiple queries. Use them when you want to stack compatible query results together.
  - `:except` and `:except_all` are used to subtract one result set from another. Use them when you want rows from one query that do not appear in another.
  - `:intersect` and `:intersect_all` are used to return rows shared by multiple result sets. Use them when you want only the overlap between queries.

  ## Joins and association shorthand

  `:join` supports explicit source-family keys such as `association:`,
  `schema:`, `table:`, `query:`, `subquery:`, and `fragment:`. It also
  supports an explicit `type:` source-family selector.

  In explicit join payloads, `type:` selects the source family and
  `qualifier:` selects the join mode such as `:left` or `:inner`.

  Any key that matches a declared association on the schema is also treated as
  association shorthand:

      %{comments: %{approved: true}}

  This ensures the association binding exists and applies the nested filters to
  that binding.

  `:lock` supports three public payload families:

  * a map or keyword list with `name:`
  * a raw string lock clause
  * a unary function that receives the current query and returns an
    `Ecto.Query`
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.Config
  alias EctoShorts.LogUtils

  alias EctoShorts.QueryBuilders

  @logger_prefix "EctoShorts.CommonFilters"

  @typedoc """
  The set of top-level filter keys understood by `convert_params_to_filter/3`.

  Each atom is a key you can use in your filter params map or keyword list.
  Keys not listed here (and not matching a schema association name) are treated
  as direct field comparisons against the primary source.

  See the "Filter Keys" section of `EctoShorts.CommonFilters` for a description
  of what each key does and when to use it.
  """
  @type filters ::
          :all
          | :any
          | :distinct
          | :except
          | :except_all
          | :exclude
          | :first
          | :group_by
          | :having
          | :intersect
          | :intersect_all
          | :join
          | :last
          | :limit
          | :lock
          | :offset
          | :order_by
          | :or_having
          | :or_where
          | :page
          | :prepend_order_by
          | :preload
          | :put_query_prefix
          | :recursive_ctes
          | :reverse_order
          | :select
          | :select_merge
          | :subquery
          | :union
          | :union_all
          | :update
          | :where
          | :windows
          | :with_cte
          | :with_named_binding
          | :with_ties

  @filters [
    :distinct,
    :except,
    :except_all,
    :exclude,
    :first,
    :group_by,
    :having,
    :intersect,
    :intersect_all,
    :join,
    :last,
    :limit,
    :lock,
    :offset,
    :order_by,
    :or_having,
    :or_where,
    :page,
    :prepend_order_by,
    :preload,
    :put_query_prefix,
    :recursive_ctes,
    :reverse_order,
    :select,
    :select_merge,
    :subquery,
    :union,
    :union_all,
    :update,
    :where,
    :windows,
    :with_cte,
    :with_named_binding,
    :with_ties
  ]

  @doc """
  Returns the list of recognized structural filter keys.

  These are the atoms that `convert_params_to_filter/3` treats as named query
  clauses rather than direct field comparisons. Any key not in this list (and
  not matching a schema association) is treated as a field-level predicate
  against the primary source.

  ## Examples

      iex> :last in EctoShorts.CommonFilters.filters()
      true

      iex> :order_by in EctoShorts.CommonFilters.filters()
      true

      iex> :nonexistent_key in EctoShorts.CommonFilters.filters()
      false

  """
  @spec filters() :: list(filters())
  def filters, do: @filters

  # ------------------------------------------------------------------------
  # IMPLEMENTATION CONTRACT
  # ------------------------------------------------------------------------
  #
  # Read before modifying the function convert_params_to_filter/3 or any
  # code it calls.
  #
  # A params map or keyword list is a collection of operations, not a
  # single operation node.
  # Do NOT pattern match on a partial map shape such as %{field: name} to
  # infer meaning for the whole container.
  # Meaning is assigned at the {key, value} entry boundary.
  #
  # Walk params with a reducer or recursive function that processes each
  # entry in evaluation order and carries the accumulated query forward.
  # Recurse into nested param containers for grouping, binding selection,
  # association scopes, and other structural forms.
  #
  # Dispatch each {key, value} entry to the appropriate builder or
  # handler.
  # Preserve duplicate-key and ordering semantics by accepting keyword
  # lists where order or repetition is meaningful.
  #
  # Treat unknown non-filter keys as field-level operations at the current
  # scope instead of inventing ad hoc container-level pattern matches.
  #
  # Keep the recursive walk explicit: the reader must be able to see where
  # traversal happens, where meaning is assigned, and where the
  # accumulated query is updated.

  @doc """
  Builds an `Ecto.Query` from `source` by applying each entry in `params`.

  `source` may be a schema module, an `{source, schema}` tuple, or an existing
  `Ecto.Query`. `params` may be a map or keyword list. Keyword lists preserve
  duplicate keys and are therefore the right choice when clause order matters.

  ## Options

  * `:sorter` - receives the normalized keyword list and returns it in the
    order to evaluate
  * `:query_builder` - custom `EctoShorts.QueryBuilder`
  * `:query_provider` - provider used by query families such as joins and
    locks
  * `:dynamic_builder` - per-call override of the dynamic expression builder
    module (the adapter that turns predicate filters into `Ecto.Query.dynamic`
    expressions); defaults to auto-detection from the repo's adapter — only
    `Ecto.Adapters.Postgres` ships today. Note: the app-config form of this
    setting uses the key `:dynamic_builder_module` instead.

  ## Examples

      iex> CommonFilters.convert_params_to_filter(Post, %{published: true}, [])
      #Ecto.Query<from p0 in Post, where: p0.published == ^true>

      iex> CommonFilters.convert_params_to_filter(Post, %{and: %{views: 5, published: true}}, [])
      #Ecto.Query<from p0 in Post, where: p0.published == ^true, where: p0.views == ^5>

      iex> CommonFilters.convert_params_to_filter(
      ...>   Post,
      ...>   [where: %{published: true}, or_where: %{title: "Draft"}],
      ...>   []
      ...> )
      #Ecto.Query<from p0 in Post, where: p0.published == ^true, or_where: p0.title == ^"Draft">

      iex> CommonFilters.convert_params_to_filter(
      ...>   source,
      ...>   %{as: %{author: %{select: :first_name}}},
      ...>   []
      ...> )
      #Ecto.Query<...>
  """
  @spec convert_params_to_filter(source :: term(), params :: map() | keyword()) :: Ecto.Query.t()
  @spec convert_params_to_filter(source :: term(), params :: map() | keyword(), opts :: keyword()) ::
          Ecto.Query.t()
  def convert_params_to_filter(source, params, opts \\ []) do
    query = CommonSchema.to_query(source)

    sorted =
      case opts[:sorter] do
        nil -> sort_filter_params(params)
        sorter -> sorter.(params)
      end

    reduce_filters(:where, source, query, {:as, nil}, sorted, opts)
  end

  defp reduce_filters(filter, source, query, selected_binding, params, opts) do
    if (is_map(params) and not is_struct(params)) or is_list(params) do
      Enum.reduce(params, query, &apply_filter(filter, source, &2, selected_binding, &1, opts))
    else
      LogUtils.warning(
        @logger_prefix,
        "Expected filter params to be a map or keyword list, got: #{inspect(params)}"
      )

      query
    end
  end

  defp apply_filter(filter, source, query, selected_binding, {key, params}, opts) do
    cond do
      key in [:as, :at] ->
        cond do
          is_nil(params) ->
            query

          (is_map(params) and not is_struct(params)) or is_list(params) ->
            Enum.reduce(params, query, fn {next_key, next_value}, query_acc ->
              {:ok, resolved} = resolve_binding_selector(query_acc, key, next_key)

              apply_filter(
                filter,
                source,
                query_acc,
                resolved,
                next_value,
                opts
              )
            end)

          true ->
            LogUtils.warning(
              @logger_prefix,
              "Expected :#{key} params to be a map or keyword list, got: #{inspect(params)}"
            )

            query
        end

      key in [:having, :or_having, :where, :or_where] ->
        cond do
          list_of_params?(params) ->
            reduce_filters(key, source, query, selected_binding, params, opts)

          params?(params) ->
            reduce_filters(key, source, query, selected_binding, params, opts)

          true ->
            QueryBuilders.build_query(key, source, query, selected_binding, params, opts)
        end

      assoc_key?(source, key) ->
        if params?(params) do
          apply_assoc_filters(filter, source, query, key, params, opts)
        else
          raise EctoShorts.FilterError,
                "association filter #{inspect(key)} expects a map or keyword list, got: #{inspect(params)}"
        end

      key in [:and, :all] ->
        if is_nil(params), do: query, else: reduce_filters(filter, source, query, selected_binding, params, opts)

      key in [:or, :any] ->
        cond do
          is_nil(params) ->
            query

          list_of_params?(params) ->
            reduce_filters(:or_where, source, query, selected_binding, params, opts)

          (is_map(params) and not is_struct(params)) or is_list(params) ->
            Enum.reduce(params, query, fn {inner_key, inner_value}, query_acc ->
              or_entries(source, query_acc, selected_binding, inner_key, inner_value, opts)
            end)

          true ->
            LogUtils.warning(
              @logger_prefix,
              "Expected :#{key} params to be a map or keyword list, got: #{inspect(params)}"
            )

            query
        end

      key in @filters ->
        QueryBuilders.build_query(key, source, query, selected_binding, params, opts)

      true ->
        QueryBuilders.build_query(filter, source, query, selected_binding, {key, params}, opts)
    end
  end

  defp apply_filter(filter, source, query, selected_binding, params, opts) do
    reduce_filters(filter, source, query, selected_binding, params, opts)
  end

  defp or_entries(source, query, selected_binding, key, value, opts) do
    QueryBuilders.build_query(:or_where, source, query, selected_binding, {key, value}, opts)
  end

  defp apply_assoc_filters(filter, source, query, key, params, opts) do
    assoc_source = get_assoc_source(source, key)

    query_acc =
      QueryBuilders.build_query(
        :join,
        source,
        query,
        {:as, nil},
        [association: [source: key, as: key]],
        opts
      )

    apply_filter(filter, assoc_source, query_acc, {:as, key}, params, opts)
  end

  defp resolve_binding_selector(_query, :at, :first) do
    {:ok, {:at, 1}}
  end

  defp resolve_binding_selector(query, :at, :last) do
    {:ok, {:at, CommonQuery.query_binding_count(query)}}
  end

  defp resolve_binding_selector(_query, :at, position) when is_integer(position) do
    max = Config.max_positional_bindings() || 10

    if position >= 1 and position <= max do
      {:ok, {:at, position}}
    else
      raise EctoShorts.FilterError,
            "binding position #{position} is out of range (max #{max})"
    end
  end

  defp resolve_binding_selector(_query, key, inner_key) do
    {:ok, {key, inner_key}}
  end

  defp get_assoc_source(source, key) do
    %{queryable: queryable} = CommonSchema.get_schema_reflection(source, :association, key)
    queryable
  end

  defp assoc_key?(source, key) do
    key in (CommonSchema.get_schema_reflection(source, :associations) || [])
  end

  defp params?(term), do: (is_map(term) and not is_struct(term)) or Keyword.keyword?(term)
  defp list_of_params?([]), do: true
  defp list_of_params?([head | _]), do: params?(head)
  defp list_of_params?(_), do: false

  @doc """
  Sorts a params map or keyword list into the standard evaluation order.

  The order produced is:

  1. `:where` entries — applied first so regular predicates narrow the result set.
  2. All other filter entries — structural filters, ordering, joins, etc.
  3. `:or_where` entries — applied after `WHERE` clauses so OR logic is not
     accidentally hoisted above normal predicates.
  4. Terminal entries (`:last`, `:subquery`) — applied last because they
     depend on the fully-built query.

  When `params` is a map, it is converted to a keyword list before sorting.
  Original key order within each group is preserved.

  `convert_params_to_filter/3` calls this automatically. Pass a custom
  `:sorter` option to that function if you need a different order.

  ## Examples

      iex> EctoShorts.CommonFilters.sort_filter_params([
      ...>   last: 5,
      ...>   or_where: %{published: false},
      ...>   where: %{active: true},
      ...>   limit: 10
      ...> ])
      [where: %{active: true}, limit: 10, or_where: %{published: false}, last: 5]

  """
  def sort_filter_params(params) do
    {where, ors, terminal, other} =
      Enum.reduce(params, {[], [], [], []}, fn {key, _} = entry, {w, o, t, rest} ->
        case key do
          :where -> {[entry | w], o, t, rest}
          :or_where -> {w, [entry | o], t, rest}
          k when k in [:last, :subquery] -> {w, o, [entry | t], rest}
          _ -> {w, o, t, [entry | rest]}
        end
      end)

    Enum.reverse(where) ++ Enum.reverse(other) ++ Enum.reverse(ors) ++ Enum.reverse(terminal)
  end
end
