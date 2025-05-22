defmodule EctoShorts.CommonQueries do
  @moduledoc since: "2.5.0"
  @moduledoc """
  `EctoShorts.CommonQueries` provides a standardized API to inspect
  and understand Ecto queries.

  The functions in this API provide information that can be used to
  generate queries dynamically, or help you to compose new queries
  or on top of existing queries. Some of the things you can figure
  out from a query includes what schemas have been defined, any
  joins have been declared, and if it is built on any subqueries.

  ## Creating a Query

  Let’s say you’re starting with a schema:

      EctoShorts.CommonQueries.to_query(EctoShorts.Schemas.Post)
      #Ecto.Query<from p in EctoShorts.Schemas.Post>

  Or maybe you’re using a custom source:

      EctoShorts.CommonQueries.to_query({"custom_source", EctoShorts.Schemas.Post})
      #Ecto.Query<from p in {"custom_source", EctoShorts.Schemas.Post}>

  Or maybe you already have a query:

      import Ecto.Query
      query = from p in EctoShorts.Schemas.Post
      EctoShorts.CommonQueries.to_query(query)

  The input can be a schema, query, or source tuple and this will give
  you back a standard `Ecto.Query` struct that you can use.

  ## Find Out What a Query Is Based On

  Want to figure out what table or schema a query is targeting?

      import Ecto.Query
      query = from p in EctoShorts.Schemas.Post, as: :post

      EctoShorts.CommonQueries.get_from_expression(query)
      %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}, ...}

  You can use the `get_from_expr/1` function that walks through the
  query and gives you the underlying `from` expression.

  ## Working With Subqueries

  When building advanced queries, you’ll often wrap one query inside
  another. You can detect if the base of your query is a subquery
  like this:

      EctoShorts.CommonQueries.has_source_subquery?(query)

  Or get the subquery itself:

      EctoShorts.CommonQueries.get_source_subquery(query)

  That’s helpful when building abstractions that need to behave differently
  depending on whether you’re working from a schema or a composed subquery.

  ## Looking Up Named Bindings

  If you’ve used `as: :post` or `as: :comments` in your query, you can
  inspect what those bindings refer to.

  To get the schema module:

      EctoShorts.CommonQueries.fetch_binding_expression_source_and_schema(query, :post, :schema)
      EctoShorts.Schemas.Post

  To get the source name (the table name):

      EctoShorts.CommonQueries.fetch_binding_expression_source_and_schema(query, :post, :source)
      "posts"

  This simplifies working with joins, nested queries, or association
  based filters.
  """

  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @type from_expr :: %Ecto.Query.FromExpr{}
  @type join_expr :: %Ecto.Query.JoinExpr{}
  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type query_source :: query() | sourceable()
  @type binding_alias :: atom()
  @type key() :: atom()

  @doc """
  Converts the given `schema_module`, or `{schema_source, schema_module}`
  to an Ecto.Query struct or returns an `Ecto.Query` struct as-is.

  ## Examples

      iex> EctoShorts.CommonQueries.to_query(EctoShorts.Schemas.Post)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>

      iex> EctoShorts.CommonQueries.to_query({"custom_source", EctoShorts.Schemas.Post})
      #Ecto.Query<from p0 in {"custom_source", EctoShorts.Schemas.Post}>

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> EctoShorts.CommonQueries.to_query(query)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>
  """
  @spec to_query(query_source()) :: query()
  def to_query(query) when is_struct(query, Ecto.Query), do: query
  def to_query(source), do: Queryable.to_query(source)

  # ---

  def fetch_source!(query) do
    with nil <- get_source(query) do
      raise "source not found, got: #{query}"
    end
  end

  def fetch_source(query) do
    with nil <- get_source(query) do
      :error
    end
  end

  def find_source(query) do
    with nil <- get_source(query) do
      {:error, :not_found}
    end
  end

  def get_source(nil), do: nil
  def get_source(%{query: query}), do: get_source(query)
  def get_source(%{from: from_expr}), do: get_source(from_expr)
  def get_source(%{source: {_, _} = source}), do: source
  def get_source(%{source: source}), do: get_source(source)

  def get_source({schema_source, schema_module}),
    do: {schema_source, schema_module} |> to_query() |> get_source()

  def get_source(schema_module) when is_atom(schema_module),
    do: schema_module |> to_query() |> get_source()

  # ---

  def fetch_expression_source!(query, binding_alias) do
    with nil <- get_expression_source(query, binding_alias) do
      raise ArgumentError,
            "binding '#{inspect(binding_alias)}' not found in query, got: #{inspect(query)}"
    end
  end

  def fetch_expression_source(query, binding_alias) do
    with nil <- get_expression_source(query, binding_alias) do
      :error
    end
  end

  def find_expression_source(query, binding_alias) do
    with nil <- get_expression_source(query, binding_alias) do
      {:error, :not_found}
    end
  end

  def get_expression_source(query, binding_alias) do
    case get_expression(query, binding_alias) do
      nil ->
        nil

      {%{assoc: _, on: _} = join_expr, _binding_position} ->
        resolve_join_expression_source(join_expr, query)

      {%{source: {_, _} = source} = _from_expr, _binding_position} ->
        source
    end
  end

  defp resolve_join_expression_source(
         %{assoc: {parent_binding_position, assoc_key}} = _join_expr,
         %{from: from_expr, joins: joins} = query
       ) do
    if parent_binding_position === 0 do
      with {_, parent_schema_module} <- get_source(from_expr) do
        {nil, fetch_association_schema_module!(parent_schema_module, assoc_key)}
      end
    else
      case Enum.at(joins, parent_binding_position) do
        nil ->
          raise ArgumentError,
                """
                parent binding not found at position #{inspect(parent_binding_position)} in query.

                query:

                #{inspect(query, pretty: true)}
                """

        %{assoc: {^parent_binding_position, ^assoc_key}} ->
          # If the join expression's assoc refers to the same binding position
          # it's at, it means the association is actually relative to the `from`
          # source so we terminate here to prevent infinite recursion.
          with {_, schema_module} <- get_source(from_expr) do
            {nil, fetch_association_schema_module!(schema_module, assoc_key)}
          end

        %{source: {_, parent_schema_module}} = _parent_join_expr ->
          assoc = parent_schema_module.__schema__(:association, assoc_key)

          {nil, assoc.queryable}

        parent_join_expr ->
          {_, parent_schema_module} = resolve_join_expression_source(parent_join_expr, query)

          assoc = parent_schema_module.__schema__(:association, assoc_key)

          {nil, assoc.queryable}
      end
    end
  end

  defp resolve_join_expression_source(%{source: {_, _} = source} = _join_expr, _query) do
    source
  end

  defp resolve_join_expression_source(%{source: source} = _join_expr, _query) do
    get_source(source)
  end

  # ---

  def fetch_expression!(query, binding_alias) do
    with nil <- get_expression(query, binding_alias) do
      raise ArgumentError,
            "binding '#{inspect(binding_alias)}' not found in query, got: #{inspect(query)}"
    end
  end

  def fetch_expression(query, binding_alias) do
    with nil <- get_expression(query, binding_alias), do: :error
  end

  def find_expression(query, binding_alias) do
    with nil <- get_expression(query, binding_alias), do: {:error, :not_found}
  end

  def get_expression(query, binding_alias) when is_struct(query, Ecto.Query) do
    extract_expression(query, 0, binding_alias)
  end

  def get_expression(query_source, binding_alias) do
    query_source
    |> to_query()
    |> extract_expression(0, binding_alias)
  end

  defp extract_expression(%{from: from_expr, joins: join_exprs} = query, pos, binding_alias)
       when is_struct(query, Ecto.Query) do
    with nil <- extract_expression(from_expr, pos, binding_alias) do
      extract_expression(join_exprs, pos, binding_alias)
    end
  end

  defp extract_expression(%{query: query} = subquery, pos, binding_alias)
       when is_struct(subquery, Ecto.SubQuery) do
    extract_expression(query, pos, binding_alias)
  end

  defp extract_expression(%{as: as, source: source} = join_expr, pos, binding_alias)
       when is_struct(join_expr, Ecto.Query.JoinExpr) do
    if as === binding_alias do
      {join_expr, pos}
    else
      extract_expression(source, pos, binding_alias)
    end
  end

  defp extract_expression(%{as: as, source: source} = from_expr, _pos, binding_alias)
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    if as === binding_alias do
      {resolve_root_expression(from_expr), 0}
    else
      extract_expression(source, 0, binding_alias)
    end
  end

  defp extract_expression([], _pos, _binding_alias), do: nil

  defp extract_expression([join_expr | join_exprs], pos, binding_alias) do
    with nil <- extract_expression(join_expr, pos + 1, binding_alias) do
      extract_expression(join_exprs, pos + 1, binding_alias)
    end
  end

  defp extract_expression(_, _, _), do: nil

  defp resolve_root_expression(%{source: {_, _}} = expr) do
    expr
  end

  defp resolve_root_expression(%{source: %{query: query}} = _expr) do
    resolve_root_expression(query)
  end

  defp resolve_root_expression(%{source: _} = expr) do
    expr
  end

  defp fetch_association_schema_module!(schema_module, key) do
    with nil <- SchemaHelpers.get_schema_association_module(schema_module, key) do
      raise KeyError,
            "association not found on schema '#{inspect(schema_module)}', got: #{inspect(key)}"
    end
  end
end
