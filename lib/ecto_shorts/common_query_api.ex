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

  alias EctoShorts.CommonQueries
  alias Ecto.Query

  alias EctoShorts.{
    DynamicExpressions,
    Utils
  }

  require Ecto.Query

  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type schema_metadata :: Ecto.Schema.Metadata.t()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type query_source :: query() | sourceable()
  @type prefix :: binary() | nil
  @type changeset :: Ecto.Changeset.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type binding_alias :: atom()

  @type condition :: :and | :or
  @type join_kind :: :association | :subquery
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
      ...> dyn_a = dynamic([q], q.name == "Fira")
      ...> dyn_b = dynamic([q], q.id > 1)
      ...> EctoShorts.CommonQueryAPI.merge_dynamic(dyn_a, :and, dyn_b)

      iex> import Ecto.Query
      ...> dyn_a = dynamic([q], q.name == "Fira")
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
      Query.dynamic([{^binding_alias, q}], ^value)
    else
      Query.dynamic([q], ^value)
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
  @spec dynamic(
          schema_module(),
          binding_alias() | nil,
          params(),
          opts()
        ) :: dynamic_expr()
  def dynamic(schema_module, binding_alias, params, opts) when is_list(params) do
    dynamic(schema_module, binding_alias, Map.new(params), opts)
  end

  def dynamic(schema_module, binding_alias, params, opts) do
    with nil <-
           build_dynamic_expression(
             schema_module,
             binding_alias,
             params,
             opts
           ) do
      dynamic(binding_alias, true)
    end
  end

  defp build_dynamic_expression(schema_module, binding_alias, params, opts) do
    {dyn, params} = Map.pop(params, :dynamic)

    params
    |> normalize_conditions()
    |> Enum.reduce(dyn, fn
      {condition, params}, dyn ->
        Utils.apply_expressions(
          dyn,
          params,
          fn {key, value}, dyn ->
            DynamicExpressions.create_dynamic(
              schema_module,
              dyn,
              binding_alias,
              condition,
              key,
              value,
              opts
            )
          end,
          opts
        )
    end)
  end

  defp normalize_conditions(params) do
    {cons, acc} =
      Enum.reduce(params, {[], []}, fn
        {:and, params}, {cons, acc} -> {[{:and, params} | cons], acc}
        {:or, params}, {cons, acc} -> {[{:or, params} | cons], acc}
        {key, value}, {cons, acc} -> {cons, [{key, value} | acc]}
      end)

    cons
    |> Kernel.++(and: acc)
    |> Enum.sort()
  end

  @doc """
  Sets the `from` clause on a query.

  ## Example

      iex> EctoShorts.CommonQueryAPI.from(EctoShorts.Schemas.Post, :post)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post>
  """
  @spec from(query_source(), binding_alias()) :: query()
  @spec from(query_source(), binding_alias() | nil, params()) :: query()
  def from(query, binding_alias, params \\ %{}) do
    prefix = params[:prefix]

    opts = params[:options] || []

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

  @doc """
  Dynamically selects fields or associations.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.select(EctoShorts.Schemas.Post, nil, true)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: p0>

      iex> EctoShorts.CommonQueryAPI.select(EctoShorts.Schemas.Post, nil, [:title])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: map(p0, [:title])>

      iex> EctoShorts.CommonQueryAPI.select(EctoShorts.Schemas.Post, nil, %{map: [:title]})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: map(p0, [:title])>

      iex> EctoShorts.CommonQueryAPI.select(EctoShorts.Schemas.Post, nil, %{struct: [:title]})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: struct(p0, [:title])>

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> expr = quote do: [:id, :title]
      ...> EctoShorts.CommonQueryAPI.select(query, nil, %{expression: expr})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: [:id, :title]>
  """
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
    if Map.has_key?(params, :expression) do
      query_select(query, binding_alias, params[:expression])
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

  @doc """
  Dynamically merges fields into an existing select.

  ## Examples

      iex> EctoShorts.CommonQueryAPI.select_merge(EctoShorts.Schemas.Post, nil, true)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: p0>

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, select: map(p, [:id])
      ...> EctoShorts.CommonQueryAPI.select_merge(query, nil, [:title])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: map(p0, [:id, :title])>

      # select using a quoted expression
      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, select: map(p, [:id])
      ...> expr = quote do: [:title]
      ...> EctoShorts.CommonQueryAPI.select_merge(query, nil, %{expression: expr})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, select: map(p0, [:id, :title])>
  """
  @spec select_merge(query_source(), binding_alias() | nil, params() | true, opts()) :: query()
  def select_merge(query, binding_alias, value, opts \\ [])

  def select_merge(query, binding_alias, true, _opts) do
    query_select_merge(query, binding_alias, true)
  end

  def select_merge(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      select_merge(query, binding_alias, Map.new(values), opts)
    else
      query_select_merge(query, binding_alias, values)
    end
  end

  def select_merge(query, binding_alias, params, opts) do
    if Map.has_key?(params, :expression) do
      query_select_merge(query, binding_alias, params[:expression])
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

  defp query_select_merge(query, binding_alias, true) do
    if binding_alias do
      Query.select_merge(query, [{^binding_alias, q}], q)
    else
      Query.select_merge(query, [q], q)
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

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, nil, nil, :association, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments)>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, nil, :comments, :association, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, nil, nil, :association, :comments)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments)>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, nil, :comments, :association, :comments, %{on: %{id: 2}})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments, on: c1.id == ^2>

      iex> EctoShorts.CommonQueryAPI.join(EctoShorts.Schemas.Post, nil, :comments, :association, :comments, %{on: %{id: %{>=: 2}}})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :comments, on: c1.id >= ^2>
  """
  def join(query, binding_alias, join_as, join_kind, key, params \\ %{}, opts \\ [])

  def join(query, binding_alias, join_as, join_kind, key, params, opts) when is_list(params) do
    join(query, binding_alias, join_as, join_kind, key, Map.new(params), opts)
  end

  def join(query, binding_alias, assoc_as, :association, key, params, opts) do
    {_, assoc_schema_module} = CommonQueries.fetch_expression_source!(query, binding_alias)

    qual = params[:qualifier] || :inner

    prefix = params[:prefix]

    on =
      params
      |> Map.get(:on, true)
      |> join_on(assoc_as, assoc_schema_module, opts)

    query_join_assoc(query, binding_alias, assoc_as, key, {qual, on, prefix})
  end

  def join(query, binding_alias, subquery_as, :subquery, subquery_data, params, opts) do
    {_, subquery_schema_module} = CommonQueries.fetch_expression_source!(query, binding_alias)

    qual = params[:qualifier] || :inner

    prefix = params[:prefix]

    on =
      params
      |> Map.get(:on, true)
      |> join_on(subquery_as, subquery_schema_module, opts)

    query_join_subquery(
      query,
      binding_alias,
      subquery_as,
      subquery_data,
      {qual, on, prefix}
    )
  end

  defp query_join_assoc(query, binding_alias, assoc_as, key, {qual, on, prefix}) do
    if is_nil(assoc_as) or assoc_as === false do
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
      Query.with_named_binding(query, assoc_as, fn query, assoc_as ->
        if binding_alias do
          Query.join(
            query,
            qual,
            [{^binding_alias, q}],
            assoc(q, ^key),
            as: ^assoc_as,
            on: ^on,
            prefix: ^prefix
          )
        else
          Query.join(
            query,
            qual,
            [q],
            assoc(q, ^key),
            as: ^assoc_as,
            on: ^on,
            prefix: ^prefix
          )
        end
      end)
    end
  end

  defp query_join_subquery(
         query,
         binding_alias,
         subquery_as,
         subquery_data,
         {qual, on, prefix}
       ) do
    if is_nil(subquery_as) or subquery_as === false do
      if binding_alias do
        Query.join(
          query,
          qual,
          [{^binding_alias, q}],
          subquery(subquery_data),
          on: ^on,
          prefix: ^prefix
        )
      else
        Query.join(
          query,
          qual,
          [q],
          subquery(subquery_data),
          on: ^on,
          prefix: ^prefix
        )
      end
    else
      Query.with_named_binding(query, subquery_as, fn query, subquery_as ->
        if binding_alias do
          Query.join(
            query,
            qual,
            [{^binding_alias, q}],
            subquery(subquery_data),
            as: ^subquery_as,
            on: ^on,
            prefix: ^prefix
          )
        else
          Query.join(
            query,
            qual,
            [q],
            subquery(subquery_data),
            as: ^subquery_as,
            on: ^on,
            prefix: ^prefix
          )
        end
      end)
    end
  end

  defp join_on(true, _binding_alias, _schema_module, _opts) do
    true
  end

  defp join_on(params, binding_alias, schema_module, opts) do
    dynamic(schema_module, binding_alias, params, opts)
  end

  def or_where(query, binding_alias, params, opts) when is_list(params) do
    if Keyword.keyword?(params) do
      or_where(query, binding_alias, Map.new(params), opts)
    else
      Enum.reduce(params, query, fn param, query ->
        or_where(query, binding_alias, param, opts)
      end)
    end
  end

  def or_where(query, binding_alias, params, opts) do
    if Map.has_key?(params, :expression) do
      do_or_where(query, binding_alias, params[:expression])
    else
      {schema_module, params} = Map.pop(params, :queryable)

      schema_module =
        with nil <- schema_module do
          {_schema_source, schema_module} =
            CommonQueries.fetch_expression_source!(query, binding_alias)

          schema_module
        end

      expr = dynamic(schema_module, binding_alias, params, opts)

      do_or_where(query, nil, expr)
    end
  end

  defp do_or_where(query, binding_alias, expr) do
    if binding_alias do
      Query.or_where(query, [{^binding_alias, q}], ^expr)
    else
      Query.or_where(query, [q], ^expr)
    end
  end

  @spec where(any(), any(), maybe_improper_list() | map(), any()) :: any()
  def where(query, binding_alias, params, opts) when is_list(params) do
    if Keyword.keyword?(params) do
      where(query, binding_alias, Map.new(params), opts)
    else
      Enum.reduce(params, query, fn param, query ->
        where(query, binding_alias, param, opts)
      end)
    end
  end

  def where(query, binding_alias, params, opts) do
    if Map.has_key?(params, :expression) do
      do_where(query, binding_alias, params[:expression])
    else
      {schema_module, params} = Map.pop(params, :queryable)

      schema_module =
        with nil <- schema_module do
          {_, schema_module} = CommonQueries.fetch_expression_source!(query, binding_alias)

          schema_module
        end

      expr = dynamic(schema_module, binding_alias, params, opts)

      do_where(query, nil, expr)
    end
  end

  defp do_where(query, binding_alias, expr) do
    if binding_alias do
      Query.where(query, [{^binding_alias, q}], ^expr)
    else
      Query.where(query, [q], ^expr)
    end
  end
end
