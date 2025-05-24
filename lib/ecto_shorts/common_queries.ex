defmodule EctoShorts.CommonQueries do
  @moduledoc since: "2.5.0"
  @moduledoc """
  This module helps you explore and understand the structure of an Ecto query.

  If If you’re working with a query that’s been built up in steps, such as one
  that includes joins, subqueries, or dynamic sources, these functions help you
  examine the query and understand how it’s structured.

  For example, you can use these helpers to:

  - Find out what table or schema the query starts from
  - Look up a join or binding by its alias
  - Traverse nested subqueries and extract their source
  """

  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @type from_expr :: %Ecto.Query.FromExpr{}
  @type join_expr :: %Ecto.Query.JoinExpr{}
  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source() | nil, schema() | nil}
  @type queryable_input :: schema() | schema_source()
  @type query_source :: query() | queryable_input()
  @type binding_alias :: atom() | nil
  @type key() :: atom()

  @doc """
  Converts the given `schema`, or `{source, schema}` to an `Ecto.Query` struct
  or returns an `Ecto.Query` struct as-is.

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

  @doc """
  Returns `true` if the given `query` or `expression` contains a nested subquery.

  ## Examples

      iex> EctoShorts.CommonQueries.has_subquery?(%{source: %{query: %Ecto.Query{}}})
      true
  """
  @spec has_subquery?(from_expr() | join_expr() | query() | subquery() | any()) :: true | false
  def has_subquery?(%{from: %{source: %{query: _}}}), do: true
  def has_subquery?(%{source: %{query: _}}), do: true
  def has_subquery?(%{query: query}), do: has_subquery?(query)
  def has_subquery?(_), do: false

  @doc """
  Returns the inner `query` or raises an error if not found.
  """
  @spec fetch_inner_query!(from_expr() | join_expr() | query() | subquery() | any()) ::
          query() | nil
  def fetch_inner_query!(query_or_expr) do
    with nil <- get_inner_query(query_or_expr) do
      raise ArgumentError, "subquery not found: #{inspect(query_or_expr)}"
    end
  end

  @doc """
  Returns the inner `query` inside the `source` of the given `query` or `expression`.
  """
  @spec get_inner_query(from_expr() | join_expr() | query() | subquery() | any()) :: query() | nil
  def get_inner_query(%{from: %{source: %{query: inner_query}}}), do: inner_query
  def get_inner_query(%{source: %{query: inner_query}}), do: inner_query
  def get_inner_query(%{query: query}), do: get_inner_query(query)
  def get_inner_query(_), do: nil

  @doc """
  Returns the `source` of the given `query` or `expression` otherwise raises an
  error if not found.

  ## Examples

      iex> EctoShorts.CommonQueries.fetch_source!({"posts", EctoShorts.Schemas.Post})
      {"posts", EctoShorts.Schemas.Post}
  """
  @spec fetch_source!(
          from_expr()
          | join_expr()
          | query()
          | subquery()
          | schema_source()
          | schema()
          | any()
          | nil
        ) :: schema_source() | source() | nil
  def fetch_source!(query_or_expr) do
    with nil <- get_schema_source(query_or_expr) do
      raise ArgumentError, "source not found: #{inspect(query_or_expr)}"
    end
  end

  @doc """
  Returns the `source` of the given `query` or `expression` otherwise `:error`.
  """
  @spec fetch_source(
          from_expr()
          | join_expr()
          | query()
          | subquery()
          | schema_source()
          | schema()
          | any()
          | nil
        ) :: schema_source() | source() | nil
  def fetch_source(query_or_expr) do
    with nil <- get_schema_source(query_or_expr) do
      :error
    end
  end

  @doc """
  Returns the `source` for the given `schema`, `query`, or `expression` or `nil`.

  ## Examples

      iex> EctoShorts.CommonQueries.get_schema_source({"posts", EctoShorts.Schemas.Post})
      {"posts", EctoShorts.Schemas.Post}
  """
  @spec get_schema_source(
          from_expr()
          | join_expr()
          | query()
          | subquery()
          | schema_source()
          | schema()
          | any()
          | nil
        ) :: schema_source() | source() | nil
  def get_schema_source(nil), do: nil
  def get_schema_source(%{source: {_, _} = source}), do: source
  def get_schema_source(%{source: source}) when is_binary(source), do: source
  def get_schema_source(%{source: source}), do: get_schema_source(source)
  def get_schema_source(%{query: query}), do: get_schema_source(query)
  def get_schema_source(%{from: from_expr}), do: get_schema_source(from_expr)

  def get_schema_source({source, schema}),
    do: {source, schema} |> to_query() |> get_schema_source()

  def get_schema_source(schema) when is_atom(schema),
    do: schema |> to_query() |> get_schema_source()

  def get_schema_source(_), do: nil

  @doc """
  Returns the root binding expression that defines the query’s data source.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in {"posts", EctoShorts.Schemas.Post}, where: p.published == true
      ...> EctoShorts.CommonQueries.get_base_expr(query)
  """
  @spec get_base_expr(from_expr() | join_expr() | query() | subquery()) ::
          from_expr() | join_expr()
  def get_base_expr(query_or_expr) do
    case extract_base_expr(query_or_expr) || query_or_expr do
      %{source: {_, _}} = base_expr ->
        base_expr

      %{source: source} = base_expr when is_binary(source) ->
        base_expr

      expr ->
        raise ArgumentError,
              "expected a `from` or `join` expression with a `:source` value of type {binary() | nil, module() | nil} " <>
                "or a database table name as a binary, but got: #{inspect(expr)}"
    end
  end

  defp extract_base_expr(nil), do: nil
  defp extract_base_expr(%{source: {_, _}} = expr), do: expr
  defp extract_base_expr(%{source: source} = expr) when is_binary(source), do: expr
  defp extract_base_expr(%{source: source}), do: extract_base_expr(source)
  defp extract_base_expr(%{query: query}), do: extract_base_expr(query)
  defp extract_base_expr(%{from: from_expr}), do: extract_base_expr(from_expr)
  defp extract_base_expr(_), do: nil

  @doc """
  Similar to `validate_schema_source/2` and raises an error if the source is
  not a tuple with a schema.
  """
  @spec validate_schema_source!(query(), binding_alias()) :: schema_source()
  def validate_schema_source!(query, binding_alias) do
    case validate_schema_source(query, binding_alias) do
      {:error, term} ->
        raise ArgumentError,
              "Expected a source tuple with a schema, got: #{inspect(term)}. " <>
                "A valid source should be a `schema` or a tuple in the form of {source, schema}, where schema is a module."

      {:ok, schema_source} ->
        schema_source
    end
  end

  @doc """
  Validates that the source associated with a given binding is a tuple
  containing a table name and a schema module.

  Returns a tuple `{source, schema}` if the source is a tuple with a
  schema module otherwise `{:error, term}`
  """
  @spec validate_schema_source(query(), binding_alias()) ::
          {:ok, schema_source()} | {:error, {source() | nil} | source()}
  def validate_schema_source(query, binding_alias) do
    case fetch_binding_expr_source!(query, binding_alias) do
      {source, nil} -> {:error, {source, nil}}
      {source, schema} when is_atom(schema) -> {:ok, {source, schema}}
      source -> {:error, source}
    end
  end

  @doc """
  Returns the `source` of the binding in the given `query` and raises an error if not found.
  """
  @spec fetch_binding_expr_source!(query(), binding_alias()) :: schema_source() | source()
  def fetch_binding_expr_source!(query, binding_alias) do
    with nil <- get_binding_expr_source(query, binding_alias) do
      raise ArgumentError,
            "binding '#{inspect(binding_alias)}' not found in query, got: #{inspect(query)}"
    end
  end

  @doc """
  Returns the `source` of the binding in the given `query`, or `{:error, :not_found}` if not found.
  """
  @spec find_binding_expr_source(query(), binding_alias()) ::
          {:ok, schema_source() | source()} | {:error, :not_found}
  def find_binding_expr_source(query, binding_alias) do
    case get_binding_expr_source(query, binding_alias) do
      nil -> {:error, :not_found}
      source -> {:ok, source}
    end
  end

  @doc """
  Returns the `source` of the binding in the given `query`.

  ## Examples

      iex> import Ecto.Query
      ...> query =
      ...>  from p in EctoShorts.Schemas.Post,
      ...>    join: c in assoc(p, :comments),
      ...>    on: c.post_id == p.id,
      ...>    as: :comments,
      ...>    join: u in assoc(p, :author),
      ...>    as: :author,
      ...>    on: u.id == c.author_id
      ...> EctoShorts.CommonQueries.get_binding_expr_source(query, :author)
      {nil, EctoShorts.Schemas.User}
  """
  @spec get_binding_expr_source(query() | schema_source() | schema(), binding_alias()) ::
          schema_source() | source() | nil
  def get_binding_expr_source(query, binding_alias) do
    case get_binding_expr(query, binding_alias) do
      nil ->
        nil

      {%{assoc: _, on: _} = join_expr, binding_position} ->
        with nil <- resolve_join_expr_source(join_expr, query) do
          raise ArgumentError,
                """
                join expression source not found in query.

                expression:

                #{inspect(join_expr, pretty: true)}

                binding position:

                #{binding_position}

                query:

                #{inspect(query, pretty: true)}
                """
        end

      {%{source: source} = _expr, _binding_position} ->
        source
    end
  end

  defp resolve_join_expr_source(
         %{assoc: {parent_binding_position, assoc_key}} = join_expr,
         %{from: from_expr, joins: joins} = query
       ) do
    if parent_binding_position === 0 do
      with {_, parent_schema} <- get_schema_source(from_expr) do
        {nil, fetch_association_schema!(parent_schema, assoc_key)}
      end
    else
      case Enum.at(joins, parent_binding_position) do
        nil ->
          # If the parent binding for the join expr does not exist in the
          # top level of the query if might exist in a subquery so we
          # have to continue searching.
          if has_subquery?(from_expr) do
            resolve_join_expr_source(join_expr, get_inner_query(query))
          end

        %{assoc: {^parent_binding_position, ^assoc_key}} ->
          # If the join expr's assoc refers to the same binding position
          # it's at, it means the association is actually relative to the `from`
          # source so we terminate here to prevent infinite recursion.
          with {_, schema} <- get_schema_source(from_expr) do
            {nil, fetch_association_schema!(schema, assoc_key)}
          end

        %{source: {_, parent_schema}} = _parent_join_expr ->
          assoc = parent_schema.__schema__(:association, assoc_key)

          {nil, assoc.queryable}

        parent_join_expr ->
          {_, parent_schema} = resolve_join_expr_source(parent_join_expr, query)

          assoc = parent_schema.__schema__(:association, assoc_key)

          {nil, assoc.queryable}
      end
    end
  end

  defp resolve_join_expr_source(%{source: source} = _join_expr, _query) do
    get_schema_source(source)
  end

  @doc """
  Same as `get_binding_expr/2`, but raises if the alias isn’t found.
  """
  @spec fetch_binding_expr!(query() | schema_source() | schema(), binding_alias()) ::
          {from_expr() | join_expr(), non_neg_integer()}
  def fetch_binding_expr!(query, binding_alias) do
    with nil <- get_binding_expr(query, binding_alias) do
      raise ArgumentError,
            "binding '#{inspect(binding_alias)}' not found in query, got: #{inspect(query)}"
    end
  end

  @doc """
  Returns a binding by alias and returns either the result or `{:error, :not_found}`.
  """
  @spec find_binding_expr(query() | schema_source() | schema(), binding_alias()) ::
          {:ok, {from_expr() | join_expr(), non_neg_integer()}} | {:error, :not_found}
  def find_binding_expr(query, binding_alias) do
    case get_binding_expr(query, binding_alias) do
      nil -> {:error, :not_found}
      {expr, binding_position} -> {:ok, {expr, binding_position}}
    end
  end

  @doc """
  Looks up a binding in the query using its alias and returns the expression and
  its position.

  If `binding_alias` is `nil` this function will always return the base from
  expression of the given `query`.
  """
  @spec get_binding_expr(query() | schema_source() | schema(), binding_alias()) ::
          {from_expr() | join_expr(), non_neg_integer()} | nil
  def get_binding_expr(query, binding_alias) when is_struct(query, Ecto.Query) do
    extract_binding_expr(query, 0, binding_alias)
  end

  def get_binding_expr(query_source, binding_alias) do
    case query_source |> to_query() |> extract_binding_expr(0, binding_alias) do
      {from_expr, binding_position} when is_struct(from_expr, Ecto.Query.FromExpr) ->
        {get_base_expr(from_expr), binding_position}

      val ->
        val
    end
  end

  defp extract_binding_expr(%{from: from_expr, joins: join_exprs} = query, pos, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      {get_base_expr(from_expr), 0}
    else
      with nil <- extract_binding_expr(from_expr, pos, binding_alias) do
        extract_binding_expr(join_exprs, pos, binding_alias)
      end
    end
  end

  defp extract_binding_expr(%{query: query} = subquery, pos, binding_alias)
       when is_struct(subquery, Ecto.SubQuery) do
    extract_binding_expr(query, pos, binding_alias)
  end

  defp extract_binding_expr(%{as: as, source: source} = join_expr, pos, binding_alias)
       when is_struct(join_expr, Ecto.Query.JoinExpr) do
    if as === binding_alias do
      {join_expr, pos}
    else
      extract_binding_expr(source, pos, binding_alias)
    end
  end

  defp extract_binding_expr(%{as: as, source: source} = from_expr, _pos, binding_alias)
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    if as === binding_alias do
      {from_expr, 0}
    else
      extract_binding_expr(source, 0, binding_alias)
    end
  end

  defp extract_binding_expr([], _pos, _binding_alias), do: nil

  defp extract_binding_expr([join_expr | join_exprs], pos, binding_alias) do
    with nil <- extract_binding_expr(join_expr, pos + 1, binding_alias) do
      extract_binding_expr(join_exprs, pos + 1, binding_alias)
    end
  end

  defp extract_binding_expr(_, _, _), do: nil

  defp fetch_association_schema!(schema, key) do
    with nil <- SchemaHelpers.get_schema_association_module(schema, key) do
      raise KeyError,
            "association not found on schema '#{inspect(schema)}', got: #{inspect(key)}"
    end
  end
end
