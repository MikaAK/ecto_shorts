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

  alias Ecto.Query
  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.Config
  alias EctoShorts.DynamicBuilders
  alias EctoShorts.Logger

  alias EctoShorts.CommonFilters.{
    Distinct,
    GroupBy,
    Having,
    Join,
    Last,
    Limit,
    Lock,
    Offset,
    OrderBy,
    Preload,
    Select,
    SetOperation,
    SubQuery,
    Update,
    Windows,
    WithCte,
    WithTies,
    WithNamedBinding
  }

  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters"

  @binding_operator [:as, :at]

  @uniqueness_filters [:distinct]
  @grouping_filters [:group_by]
  @post_aggregate_filters [:having, :or_having]
  @association_filters [:join]
  @terminal_result_filters [:last]
  @sorting_filters [:order_by, :prepend_order_by, :reverse_order]
  @predicate_filters [:where, :or_where]
  @eager_load_filters [:preload]
  @namespace_filters [:put_query_prefix]
  @recursive_cte_filters [:recursive_ctes]
  @projection_filters [:select, :select_merge]
  @set_composition_filters [:except, :except_all, :intersect, :intersect_all, :union, :union_all]
  @nested_query_filters [:subquery]
  @removal_filters [:exclude]
  @concurrency_filters [:lock]
  @cardinality_filters [:limit, :first]
  @pagination_filters [:offset]
  @mutation_filters [:update]
  @window_function_filters [:windows]
  @cte_filters [:with_cte]
  @tie_handling_filters [:with_ties]
  @binding_filters [:with_named_binding]

  @all_filters Enum.concat([
                 @uniqueness_filters,
                 @grouping_filters,
                 @post_aggregate_filters,
                 @association_filters,
                 @terminal_result_filters,
                 @sorting_filters,
                 @eager_load_filters,
                 @namespace_filters,
                 @recursive_cte_filters,
                 @window_function_filters,
                 @cte_filters,
                 @tie_handling_filters,
                 @projection_filters,
                 @set_composition_filters,
                 @nested_query_filters,
                 @removal_filters,
                 @concurrency_filters,
                 @cardinality_filters,
                 @pagination_filters,
                 @mutation_filters,
                 @binding_filters,
                 @predicate_filters
               ])

  @behaviour EctoShorts.Adapter.QueryBuilder

  @doc """
  Builds an `Ecto.Query` from `source` by applying each entry in `params`.

  `source` may be a schema module, an `{source, schema}` tuple, or an existing
  `Ecto.Query`. `params` may be a map or keyword list. Keyword lists preserve
  duplicate keys and are therefore the right choice when clause order matters.

  ## Options

  * `:sorter` - receives the normalized keyword list and returns it in the
    order to evaluate
  * `:query_builder` - custom `EctoShorts.Adapter.QueryBuilder`
  * `:query_provider` - provider used by query families such as joins and
    locks

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
    sorter = opts[:sorter] || (&sort_filter_params/1)

    params
    |> to_keyword()
    |> sorter.()
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      apply_filters(:where, source, query_acc, {:as, nil}, {key, value}, opts)
    end)
  end

  defp apply_filters(filter, source, query, selected_binding, {key, term}, opts) do
    cond do
      key in @binding_operator ->
        Enum.reduce(term, query, fn {inner_key, inner_value}, query_acc ->
          case resolve_binding_selector(query_acc, key, inner_key) do
            :skip ->
              query_acc

            resolved ->
              apply_filters(
                filter,
                source,
                query_acc,
                resolved,
                inner_value,
                opts
              )
          end
        end)

      key in @predicate_filters ->
        reduce_filter_group_or_build(key, source, query, selected_binding, term, opts)

      key in @post_aggregate_filters ->
        reduce_filter_group_or_build(key, source, query, selected_binding, term, opts)

      association_key?(source, key) ->
        if container?(term) do
          query
          |> ensure_association_binding(source, key, opts)
          |> reduce_association_filters(filter, source, key, term, opts)
        else
          Logger.warning(
            @logger_prefix,
            "Expected association filter value to be a map or keyword list, got: #{inspect(term)}"
          )

          query
        end

      key in @all_filters ->
        build_query(key, source, query, selected_binding, term, opts)

      key === :and ->
        if filter_group_list?(term) do
          Enum.reduce(term, query, fn entry, query_acc ->
            entry
            |> to_keyword()
            |> then(&apply_filters(filter, source, query_acc, selected_binding, &1, opts))
          end)
        else
          term
          |> to_keyword()
          |> Enum.reduce(query, fn {inner_key, inner_value}, query_acc ->
            apply_filters(
              filter,
              source,
              query_acc,
              selected_binding,
              {inner_key, inner_value},
              opts
            )
          end)
        end

      key === :or ->
        if filter_group_list?(term) do
          Enum.reduce(term, query, fn entry, query_acc ->
            entry
            |> to_keyword()
            |> then(&apply_filters(:or_where, source, query_acc, selected_binding, &1, opts))
          end)
        else
          term
          |> to_keyword()
          |> Enum.reduce(query, fn {inner_key, inner_value}, query_acc ->
            or_entries(source, query_acc, selected_binding, inner_key, inner_value, opts)
          end)
        end

      true ->
        build_query(filter, source, query, selected_binding, {key, term}, opts)
    end
  end

  defp apply_filters(filter, source, query, selected_binding, term, opts) do
    Enum.reduce(term, query, &apply_filters(filter, source, &2, selected_binding, &1, opts))
  end

  defp reduce_filter_group_or_build(filter, source, query, selected_binding, term, opts) do
    cond do
      filter_group_list?(term) ->
        Enum.reduce(term, query, fn entry, query_acc ->
          entry
          |> to_keyword()
          |> then(&apply_filters(filter, source, query_acc, selected_binding, &1, opts))
        end)

      container?(term) ->
        term
        |> to_keyword()
        |> Enum.reduce(query, fn {inner_key, inner_value}, query_acc ->
          apply_filters(
            filter,
            source,
            query_acc,
            selected_binding,
            {inner_key, inner_value},
            opts
          )
        end)

      true ->
        build_query(filter, source, query, selected_binding, term, opts)
    end
  end

  defp or_entries(source, query, selected_binding, key, value, opts) do
    build_query(:or_where, source, query, selected_binding, {key, value}, opts)
  end

  defp resolve_binding_selector(_query, :at, :first), do: {:at, 1}

  defp resolve_binding_selector(query, :at, :last),
    do: {:at, CommonQuery.query_binding_count(query)}

  defp resolve_binding_selector(_query, :at, position) when is_integer(position) do
    max = Config.max_positional_bindings() || 10

    if position >= 1 and position <= max do
      {:at, position}
    else
      Logger.warning(
        @logger_prefix,
        "Positional binding :at position #{position} is out of range " <>
          "(compiled max: #{max}). Filter skipped."
      )

      :skip
    end
  end

  defp resolve_binding_selector(_query, key, inner_key), do: {key, inner_key}

  defp reduce_association_filters(query, filter, source, key, term, opts) do
    term
    |> to_keyword()
    |> Enum.reduce(query, fn {inner_key, inner_value}, query_acc ->
      apply_filters(filter, source, query_acc, {:as, key}, {inner_key, inner_value}, opts)
    end)
  end

  defp ensure_association_binding(query, source, key, opts) do
    build_query(
      :with_named_binding,
      source,
      query,
      {:as, nil},
      %{key => %{join: [association: [source: key, as: key]]}},
      opts
    )
  end

  defp to_keyword(map) when is_map(map) and not is_struct(map),
    do: map |> Map.to_list() |> to_keyword()

  defp to_keyword([]), do: []
  defp to_keyword([head | tail]), do: [to_keyword(head) | to_keyword(tail)]
  defp to_keyword({k, v}), do: {k, to_keyword(v)}
  defp to_keyword(term), do: term

  defp association_key?(source, key) do
    key in (CommonSchema.get_schema_reflection(source, :associations) || [])
  end

  defp container?(term) do
    (is_map(term) and not is_struct(term)) or Keyword.keyword?(term)
  end

  defp filter_group_list?([]), do: true
  defp filter_group_list?([head | _]), do: container?(head)
  defp filter_group_list?(_), do: false

  @impl EctoShorts.Adapter.QueryBuilder
  @doc """
  Applies a single filter entry to the query.

  This is the `EctoShorts.Adapter.QueryBuilder` implementation for
  `EctoShorts.CommonFilters`. It dispatches `{filter, term}` to the
  appropriate internal builder module via `EctoShorts.CommonFilters.API`,
  or delegates to a custom `:query_builder` module when one is configured.

  `filter` is the filter-group atom, such as `:where`, `:join`, or
  `:order_by`. `selected_binding` is the active binding selector
  (`{:as, atom()}` or `{:at, pos_integer()}`). `term` is either a
  `{field, value}` pair for field filters or the raw filter payload for
  structural filters.

  Custom query builder implementations can call this function to fall
  through to the default dispatch after applying their own logic:

      defmodule MyApp.CustomQueryBuilder do
        @behaviour EctoShorts.Adapter.QueryBuilder

        @impl true
        def build_query(filter, source, query, selected_binding, term, opts) do
          EctoShorts.CommonFilters.build_query(filter, source, query, selected_binding, term, opts)
        end
      end

  If `opts[:query_builder]` points to a module that does not export
  `build_query/6`, the function logs a warning and returns the query
  unchanged. If `:query_builder` is present but is not a module, it raises
  `ArgumentError`.
  """
  def build_query(filter, source, query, selected_binding, term, opts) do
    case opts[:query_builder] || Config.query_builder() do
      nil ->
        dispatch_build_query(filter, source, query, selected_binding, term, opts)

      module when is_atom(module) ->
        if function_exported?(module, :build_query, 6) do
          module.build_query(filter, source, query, selected_binding, term, opts)
        else
          Logger.warning(
            @logger_prefix,
            "Module does not export the required function build_query/6: #{inspect(module)}"
          )

          query
        end

      term ->
        raise ArgumentError, "Expect :query_builder option to a module, got: #{inspect(term)}"
    end
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @uniqueness_filters do
    Distinct.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:last, source, query, selected_binding, term, opts) do
    Last.build_query(:last, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:join, source, query, selected_binding, term, opts) do
    Join.build_query(:join, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @grouping_filters do
    GroupBy.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @post_aggregate_filters do
    Having.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @sorting_filters do
    OrderBy.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:preload, source, query, selected_binding, term, opts) do
    Preload.build_query(:preload, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:subquery, source, query, selected_binding, term, opts) do
    SubQuery.build_query(:subquery, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:put_query_prefix, _source, query, _selected_binding, prefix, _opts) do
    Query.put_query_prefix(query, prefix)
  end

  defp dispatch_build_query(:recursive_ctes, _source, query, _selected_binding, value, _opts) do
    Query.recursive_ctes(query, value)
  end

  defp dispatch_build_query(:windows, source, query, selected_binding, term, opts) do
    Windows.build_query(:windows, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:with_cte, source, query, selected_binding, term, opts) do
    WithCte.build_query(:with_cte, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:with_ties, source, query, selected_binding, term, opts) do
    WithTies.build_query(:with_ties, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @projection_filters do
    Select.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @set_composition_filters do
    SetOperation.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:exclude, _source, query, _selected_binding, term, _opts) do
    term
    |> List.wrap()
    |> Enum.reduce(query, fn field, query_acc ->
      Query.exclude(query_acc, field)
    end)
  end

  defp dispatch_build_query(:lock, source, query, selected_binding, term, opts) do
    Lock.build_query(:lock, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @cardinality_filters do
    Limit.build_query(filter, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:offset, source, query, selected_binding, term, opts) do
    Offset.build_query(:offset, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:update, source, query, selected_binding, term, opts) do
    Update.build_query(:update, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(:with_named_binding, source, query, selected_binding, term, opts) do
    WithNamedBinding.build_query(:with_named_binding, source, query, selected_binding, term, opts)
  end

  defp dispatch_build_query(filter, source, query, selected_binding, term, opts)
       when filter in @predicate_filters do
    dyn = DynamicBuilders.build_dynamic(source, selected_binding, term, opts)

    case filter do
      :where -> Query.where(query, ^dyn)
      :or_where -> Query.or_where(query, ^dyn)
    end
  end

  defp sort_filter_params(params) do
    where_filters = Enum.filter(params, fn {key, _val} -> key === :where end)
    or_where_filters = Enum.filter(params, fn {key, _val} -> key === :or_where end)
    terminal_filters = Enum.filter(params, fn {key, _val} -> key in [:last, :subquery] end)

    other_filters =
      Enum.filter(params, fn {key, _val} -> key not in [:where, :or_where, :last, :subquery] end)

    where_filters
    |> Kernel.++(other_filters)
    |> Kernel.++(or_where_filters)
    |> Kernel.++(terminal_filters)
  end
end
