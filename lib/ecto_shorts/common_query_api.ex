defmodule EctoShorts.CommonQueryAPI do
  @moduledoc since: "2.5.0"
  @moduledoc """
  `EctoShorts.CommonQueryAPI` provides a standardized API for creating
  `Ecto.Query` expressions with support for bound and unbound contexts.

  This api wraps the `Ecto.Query` macro calls so you don't need to
  import `Ecto.Query` or manually writing macros like `from`, `where`,
  or `select`. You can use maps or keyword lists to drive the behaviour
  of things such as filters, joins, and ordering.

  ## Getting Started

  Here’s a simple example:

      alias EctoShorts.CommonQueryAPI

      EctoShorts.Schemas.Post
      |> CommonQueryAPI.from(as: :post)
      |> CommonQueryAPI.where(:post, %{published: true})
      |> CommonQueryAPI.order_by(:post, [asc: :inserted_at])
      |> CommonQueryAPI.limit(nil, 10)

  You don’t need to `import Ecto.Query`, and there are no macros to
  learn, just use functions that work with data.
  """
  alias Ecto.Query

  alias EctoShorts.{
    CommonQuery,
    DynamicExpressions,
    Utils
  }

  require Ecto.Query

  @type changeset :: Ecto.Changeset.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source(), schema()}
  @type schema_metadata :: Ecto.Schema.Metadata.t()
  @type schema_input :: schema() | schema_source()
  @type query_source :: query() | schema_input()
  @type prefix :: binary() | nil
  @type binding_alias :: atom() | nil
  @type condition :: :and | :or
  @type join_operation :: :association | :subquery | :query
  @type limit :: non_neg_integer()
  @type offset :: integer()
  @type key :: atom()
  @type value :: any()
  @type operator :: atom()
  @type params :: map() | keyword()
  @type opts :: keyword()

  @doc """
  Merges two dynamic expressions with `and`.

  Returns the second expression if the first is `nil`.

  ## Examples

      iex> import Ecto.Query
      ...> dyn_a = nil
      ...> dyn_b = dynamic([q], q.id > 1)
      ...> EctoShorts.CommonQueryAPI.merge_dynamic(dyn_a, :and, dyn_b)

      iex> import Ecto.Query
      ...> dyn_a = dynamic([q], q.name == "example")
      ...> dyn_b = dynamic([q], q.id > 1)
      ...> EctoShorts.CommonQueryAPI.merge_dynamic(dyn_a, :and, dyn_b)

      iex> import Ecto.Query
      ...> dyn_a = dynamic([q], q.name == "example")
      ...> dyn_b = dynamic([q], q.id > 1)
      ...> EctoShorts.CommonQueryAPI.merge_dynamic(dyn_a, :or, dyn_b)
  """
  @spec merge_dynamic(dynamic_expr() | nil, condition(), dynamic_expr()) :: dynamic_expr()
  def merge_dynamic(nil, _operator, dyn), do: dyn
  def merge_dynamic(dyn_a, :or, dyn_b), do: Query.dynamic(^dyn_a or ^dyn_b)
  def merge_dynamic(dyn_a, :and, dyn_b), do: Query.dynamic(^dyn_a and ^dyn_b)

  @doc """
  Builds a binding-aware dynamic expression.

  If a binding is provided, the dynamic will be created using that named binding.
  If no binding is given, it defaults to the root from binding.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.dynamic(nil, id: 1)
  """
  @spec dynamic(binding_alias() | nil, value()) :: dynamic_expr()
  def dynamic(binding_alias, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], ^value)
    else
      Query.dynamic([d], ^value)
    end
  end

  @doc """
  Builds a binding-aware dynamic expression.

  If a binding is provided, the dynamic will be created using that
  named binding. If no binding is given, it defaults to the root
  from binding.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.dynamic(EctoShorts.Schemas.Post, nil, %{id: 1}, [])
  """
  def dynamic(binding_alias, source, params, opts \\ [])

  def dynamic(binding_alias, source, params, opts) when is_list(params) do
    dynamic(binding_alias, source, Map.new(params), opts)
  end

  def dynamic(binding_alias, source, params, opts) do
    with nil <-
           DynamicExpressions.convert_params_to_dynamic(
             binding_alias,
             source,
             params,
             opts
           ) do
      dynamic(binding_alias, true)
    end
  end

  @doc """
  Sets the `from` clause on a query.

  ## Example

      iex> EctoShorts.CommonQueryAPI.from(EctoShorts.Schemas.Post, :post)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post>
  """
  def from(query, binding_alias, opts \\ [])

  def from(query, binding_alias, opts) when is_map(opts) do
    from(query, binding_alias, Map.to_list(opts))
  end

  def from(query, binding_alias, opts) do
    prefix = opts[:prefix]

    if binding_alias do
      query
      |> Query.from(as: ^binding_alias, prefix: ^prefix)
      |> maybe_put_query_prefix(opts)
    else
      query
      |> Query.from(prefix: ^prefix)
      |> maybe_put_query_prefix(opts)
    end
  end

  defp maybe_put_query_prefix(query, opts) do
    case opts[:query_prefix] do
      nil -> query
      prefix -> put_query_prefix(query, prefix)
    end
  end

  @doc """
  Overrides the query’s schema prefix (useful for multi-tenancy).

  ## Example

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> query = EctoShorts.CommonQueryAPI.put_query_prefix(query, "tenant_123")
      ...> query.prefix
      "tenant_123"
  """
  @spec put_query_prefix(query_source(), prefix()) :: query()
  def put_query_prefix(query, prefix) do
    Query.put_query_prefix(query, prefix)
  end

  @doc """
  Wraps a query as a subquery.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.subquery(EctoShorts.Schemas.Post)
  """
  @spec subquery(query_source() | subquery()) :: subquery()
  @spec subquery(query_source() | subquery(), opts()) :: subquery()
  def subquery(query, opts \\ []) do
    Query.subquery(query, opts)
  end

  @doc """
  Excludes a field (such as `:order_by`) from the query.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, order_by: p.inserted_at
      ...> EctoShorts.CommonQueryAPI.exclude(query, :order_by)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>
  """
  @spec exclude(query_source(), key()) :: query()
  def exclude(query, key) do
    Query.exclude(query, key)
  end

  @doc """
  Limits the number of results returned by the query.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.limit(EctoShorts.Schemas.Post, nil, 10)
  """
  @spec limit(query_source(), binding_alias() | nil, value()) :: query()
  def limit(query, binding_alias, value) do
    if binding_alias do
      Query.limit(query, [{^binding_alias, q}], ^value)
    else
      Query.limit(query, [q], ^value)
    end
  end

  @doc """
  Offsets the results returned by the query.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.offset(EctoShorts.Schemas.Post, nil, 20)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, offset: ^20>
  """
  @spec offset(query_source(), binding_alias() | nil, value()) :: query()
  def offset(query, binding_alias, value) do
    if binding_alias do
      Query.offset(query, [{^binding_alias, q}], ^value)
    else
      Query.offset(query, [q], ^value)
    end
  end

  @doc """
  Groups the results by the given value.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.group_by(EctoShorts.Schemas.Post, nil, :id)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, group_by: [p0.id]>
  """
  @spec group_by(query_source(), binding_alias() | nil, value()) :: query()
  def group_by(query, binding_alias, value) do
    if binding_alias do
      Query.group_by(query, [{^binding_alias, q}], ^value)
    else
      Query.group_by(query, [q], ^value)
    end
  end

  @doc """
  Orders the results by the given value.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.order_by(EctoShorts.Schemas.Post, nil, [asc: :inserted_at])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, order_by: [asc: p0.inserted_at]>
  """
  @spec order_by(query_source(), binding_alias() | nil, value()) :: query()
  def order_by(query, binding_alias, value) do
    if binding_alias do
      Query.order_by(query, [{^binding_alias, q}], ^value)
    else
      Query.order_by(query, [q], ^value)
    end
  end

  @doc """
  Preloads associations on the query.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.preload(EctoShorts.Schemas.Post, nil, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, preload: [:comments]>
  """
  @spec preload(query_source(), binding_alias() | nil, value()) :: query()
  def preload(query, binding_alias, value) do
    if binding_alias do
      Query.preload(query, [{^binding_alias, q}], ^value)
    else
      Query.preload(query, [q], ^value)
    end
  end

  @spec select(query_source(), binding_alias() | nil, params() | true, opts()) :: query()
  def select(query, binding_alias, value, opts \\ [])

  def select(query, binding_alias, true, _opts) do
    query_select(query, binding_alias, true)
  end

  def select(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      select(query, binding_alias, Map.new(values), opts)
    else
      query_select(query, binding_alias, {:map, values})
    end
  end

  def select(query, binding_alias, params, opts) do
    if Map.has_key?(params, :value) do
      query_select(query, binding_alias, params[:value])
    else
      Utils.apply_expressions(
        query,
        params,
        fn {key, value}, query ->
          query_select(query, binding_alias, {key, value})
        end,
        opts
      )
    end
  end

  defp query_select(query, binding_alias, true) do
    if binding_alias do
      Query.select(query, [{^binding_alias, q}], q)
    else
      Query.select(query, [q], q)
    end
  end

  defp query_select(query, binding_alias, {:map, values}) do
    if binding_alias do
      Query.select(query, [{^binding_alias, q}], map(q, ^values))
    else
      Query.select(query, [q], map(q, ^values))
    end
  end

  defp query_select(query, binding_alias, {:struct, values}) do
    if binding_alias do
      Query.select(query, [{^binding_alias, q}], struct(q, ^values))
    else
      Query.select(query, [q], struct(q, ^values))
    end
  end

  defp query_select(query, binding_alias, value) do
    if binding_alias do
      Query.select(query, [{^binding_alias, q}], ^value)
    else
      Query.select(query, [q], ^value)
    end
  end

  @spec select_merge(query_source(), binding_alias() | nil, params() | true, opts()) :: query()
  def select_merge(query, binding_alias, value, opts \\ [])

  def select_merge(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      select_merge(query, binding_alias, Map.new(values), opts)
    else
      query_select_merge(query, binding_alias, values)
    end
  end

  def select_merge(query, binding_alias, params, opts) when is_map(params) do
    if Map.has_key?(params, :value) do
      query_select_merge(query, binding_alias, params[:value])
    else
      Utils.apply_expressions(
        query,
        params,
        fn {key, value}, query ->
          query_select_merge(query, binding_alias, {key, value})
        end,
        opts
      )
    end
  end

  def select_merge(query, binding_alias, value, _opts) do
    query_select_merge(query, binding_alias, value)
  end

  defp query_select_merge(query, binding_alias, true) do
    if binding_alias do
      Query.select_merge(query, [{^binding_alias, q}], q)
    else
      Query.select_merge(query, [q], q)
    end
  end

  defp query_select_merge(query, binding_alias, {:map, keys}) do
    if binding_alias do
      Query.select_merge(query, [{^binding_alias, q}], map(q, ^keys))
    else
      Query.select_merge(query, [q], map(q, ^keys))
    end
  end

  defp query_select_merge(query, binding_alias, {:struct, keys}) do
    if binding_alias do
      Query.select_merge(query, [{^binding_alias, q}], struct(q, ^keys))
    else
      Query.select_merge(query, [q], struct(q, ^keys))
    end
  end

  defp query_select_merge(query, binding_alias, value) do
    if binding_alias do
      Query.select_merge(query, [{^binding_alias, q}], ^value)
    else
      Query.select_merge(query, [q], ^value)
    end
  end

  @doc """
  Adds a join to the query for an association or subquery.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, :association, {nil, nil}, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments)>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, :association, {nil, :comments}, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, :association, {nil, nil}, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments)>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, :association, {nil, :comments}, :comments, %{on: %{id: 2}})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments, on: c1.id == ^2>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, :association, {nil, :comments}, :comments, %{on: %{id: %{>=: 2}}})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments, on: c1.id >= ^2>
  """
  def join(query, op, join_binding, key, params \\ %{}, opts \\ [])

  def join(query, op, {binding_alias, join_as}, key, params, opts) when is_list(params) do
    join(query, op, {binding_alias, join_as}, key, Map.new(params), opts)
  end

  def join(query, :association, {binding_alias, as}, key, params, opts) do
    {source, params} = Map.pop(params, :source)

    source =
      if source !== nil do
        source
      else
        CommonQuery.get_binding_expr_source(query, binding_alias)
      end

    qual = params[:qualifier] || :inner

    prefix = params[:prefix]

    on = join_on_dynamic(as, source, params[:on], opts)

    join_assoc(query, {binding_alias, as}, key, {qual, on, prefix})
  end

  def join(query, :subquery, {binding_alias, as}, inner_query, params, opts) do
    {source, params} = Map.pop(params, :source)

    source =
      if source !== nil do
        source
      else
        CommonQuery.get_binding_expr_source(query, binding_alias)
      end

    qual = params[:qualifier] || :inner

    prefix = params[:prefix]

    on = join_on_dynamic(as, source, params[:on], opts)

    join_subquery(query, {binding_alias, as}, inner_query, {qual, on, prefix})
  end

  def join(query, :query, {binding_alias, as}, source, params, opts) do
    qual = params[:qualifier] || :inner

    prefix = params[:prefix]

    on = join_on_dynamic(as, source, params[:on], opts)

    join_query(query, {binding_alias, as}, source, {qual, on, prefix})
  end

  defp join_assoc(query, {binding_alias, as}, key, {qual, on, prefix}) do
    if is_nil(as) or as === false do
      if binding_alias do
        Query.join(
          query,
          qual,
          [{^binding_alias, q}],
          assoc(q, ^key),
          on: ^on,
          prefix: ^prefix
        )
      else
        Query.join(
          query,
          qual,
          [q],
          assoc(q, ^key),
          on: ^on,
          prefix: ^prefix
        )
      end
    else
      Query.with_named_binding(query, as, fn query, as ->
        if binding_alias do
          Query.join(
            query,
            qual,
            [{^binding_alias, q}],
            assoc(q, ^key),
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        else
          Query.join(
            query,
            qual,
            [q],
            assoc(q, ^key),
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        end
      end)
    end
  end

  defp join_subquery(query, {binding_alias, as}, inner_query, {qual, on, prefix}) do
    if is_nil(as) or as === false do
      if binding_alias do
        Query.join(
          query,
          qual,
          [{^binding_alias, q}],
          subquery(inner_query),
          on: ^on,
          prefix: ^prefix
        )
      else
        Query.join(
          query,
          qual,
          [q],
          subquery(inner_query),
          on: ^on,
          prefix: ^prefix
        )
      end
    else
      Query.with_named_binding(query, as, fn query, as ->
        if binding_alias do
          Query.join(
            query,
            qual,
            [{^binding_alias, q}],
            subquery(inner_query),
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        else
          Query.join(
            query,
            qual,
            [q],
            subquery(inner_query),
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        end
      end)
    end
  end

  defp join_query(query, {binding_alias, as}, source, {qual, on, prefix}) do
    source = normalize_source(source)

    if is_nil(as) or as === false do
      if binding_alias do
        Query.join(
          query,
          qual,
          [{^binding_alias, q}],
          ^source,
          on: ^on,
          prefix: ^prefix
        )
      else
        Query.join(
          query,
          qual,
          [q],
          ^source,
          on: ^on,
          prefix: ^prefix
        )
      end
    else
      Query.with_named_binding(query, as, fn query, as ->
        if binding_alias do
          Query.join(
            query,
            qual,
            [{^binding_alias, q}],
            ^source,
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        else
          Query.join(
            query,
            qual,
            [q],
            ^source,
            as: ^as,
            on: ^on,
            prefix: ^prefix
          )
        end
      end)
    end
  end

  defp join_on_dynamic(binding_alias, source, params, opts) when is_list(params) do
    join_on_dynamic(binding_alias, source, Map.new(params), opts)
  end

  defp join_on_dynamic(binding_alias, source, params, opts) when is_map(params) do
    dynamic(binding_alias, source, params, opts)
  end

  defp join_on_dynamic(_, _, _, _) do
    true
  end

  def or_where(query, binding_alias, values, opts \\ [])

  def or_where(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      or_where(query, binding_alias, Map.new(values), opts)
    else
      Enum.reduce(values, query, fn value, query ->
        or_where(query, binding_alias, value, opts)
      end)
    end
  end

  def or_where(query, binding_alias, params, opts) do
    {expression, params} = Map.pop(params, :value)

    {source, params} = Map.pop(params, :source)

    source =
      if source !== nil do
        source
      else
        CommonQuery.get_binding_expr_source(query, binding_alias)
      end

    if !is_nil(expression) do
      query_or_where(query, binding_alias, expression)
    else
      query_or_where(query, nil, dynamic(binding_alias, source, params, opts))
    end
  end

  defp query_or_where(query, binding_alias, expr) do
    if binding_alias do
      Query.or_where(query, [{^binding_alias, q}], ^expr)
    else
      Query.or_where(query, [q], ^expr)
    end
  end

  def where(query, binding_alias, values, opts \\ [])

  def where(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      where(query, binding_alias, Map.new(values), opts)
    else
      Enum.reduce(values, query, fn value, query ->
        where(query, binding_alias, value, opts)
      end)
    end
  end

  def where(query, binding_alias, params, opts) do
    {expression, params} = Map.pop(params, :value)

    {source, params} = Map.pop(params, :source)

    source =
      if source !== nil do
        source
      else
        CommonQuery.get_binding_expr_source(query, binding_alias)
      end

    if !is_nil(expression) do
      query_where(query, binding_alias, expression)
    else
      query_where(query, nil, dynamic(binding_alias, source, params, opts))
    end
  end

  defp query_where(query, binding_alias, expr) do
    if binding_alias do
      Query.where(query, [{^binding_alias, q}], ^expr)
    else
      Query.where(query, [q], ^expr)
    end
  end

  defp normalize_source({nil, schema}) when is_atom(schema) do
    schema
  end

  defp normalize_source({source, schema}) when is_atom(schema) do
    {source, schema}
  end

  defp normalize_source(source) when is_binary(source) do
    source
  end
end
