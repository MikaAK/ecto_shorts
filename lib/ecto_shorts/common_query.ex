defmodule EctoShorts.CommonQuery do
  @moduledoc since: "2.5.0"
  @moduledoc """
  This module helps you explore and understand the structure of an Ecto query.

  If If you’re working with a query that’s been built up in steps, such as one
  that includes joins, subqueries, or dynamic sources, these functions help you
  examine the query and understand how it’s structured.

  For example, you can use these helpers to:

  - Find out what table or schema the query starts from
  - Look up a join or binding by its alias
  - Traverse nested subqueries and lookup their source
  """

  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @type from_expr :: %Ecto.Query.FromExpr{}
  @type join_expr :: %Ecto.Query.JoinExpr{}
  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type expr_source :: source() | schema() | {source() | nil, schema() | nil}
  @type schema_input :: schema() | {source(), schema()}
  @type binding_alias :: atom() | nil
  @type key() :: atom()

  @doc """
  Converts the given `schema`, or `{source, schema}` to an `Ecto.Query` struct
  or returns an `Ecto.Query` struct as-is.

  ## Examples

      iex> EctoShorts.CommonQuery.to_query(EctoShorts.Schemas.Post)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>

      iex> EctoShorts.CommonQuery.to_query({"custom_source", EctoShorts.Schemas.Post})
      #Ecto.Query<from p0 in {"custom_source", EctoShorts.Schemas.Post}>

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> EctoShorts.CommonQuery.to_query(query)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>
  """
  @spec to_query(query() | schema_input()) :: query()
  def to_query(query) when is_struct(query, Ecto.Query), do: query
  def to_query(source), do: Queryable.to_query(source)

  @doc """
  Returns `true` if the given `query` or `expression` contains a nested subquery.

  ## Examples

      iex> EctoShorts.CommonQuery.has_subquery?(%{source: %{query: %Ecto.Query{}}})
      true
  """
  @spec has_subquery?(from_expr() | join_expr() | query() | subquery()) :: true | false
  def has_subquery?(%{from: %{source: %{query: _}}}), do: true
  def has_subquery?(%{source: %{query: _}}), do: true
  def has_subquery?(%{query: query}), do: has_subquery?(query)
  def has_subquery?(_), do: false

  @doc """
  Returns the inner `query` inside the `source` of the given `query` or `expression`.
  """
  @spec get_inner_query(query() | subquery() | from_expr() | join_expr()) :: query() | nil
  def get_inner_query(%{from: %{source: %{query: inner_query}}}), do: inner_query
  def get_inner_query(%{source: %{query: inner_query}}), do: inner_query
  def get_inner_query(%{query: query}), do: get_inner_query(query)
  def get_inner_query(_), do: nil

  @doc """
  Returns the `source` for the given `schema`, `query`, or `expression` or `nil`.

  ## Examples

      iex> EctoShorts.CommonQuery.get_source({"posts", EctoShorts.Schemas.Post})
      {"posts", EctoShorts.Schemas.Post}
  """
  @spec get_source(
          query()
          | subquery()
          | from_expr()
          | join_expr()
        ) :: expr_source() | nil
  def get_source(query_or_expr) do
    with nil <- lookup_source(query_or_expr) do
      raise ArgumentError, "source not found, got: #{inspect(query_or_expr)}"
    end
  end

  defp lookup_source(%{from: from_expr}), do: lookup_source(from_expr)
  defp lookup_source(%{query: query}), do: lookup_source(query)
  defp lookup_source(%{source: source}), do: lookup_source(source)
  defp lookup_source({_, _} = source), do: source
  defp lookup_source(source) when is_binary(source), do: source
  defp lookup_source(_), do: nil

  @doc """
  Returns the `source` of a binding in the given `query`.
  """
  def get_binding_source(query, binding_alias) do
    with nil <- lookup_binding_source(query, binding_alias) do
      raise ArgumentError,
            """
            binding source not found in query.

            alias:

            #{inspect(binding_alias)}

            query:

            #{inspect(query, pretty: true)}
            """
    end
  end

  defp lookup_binding_source(query, binding_alias) do
    case get_binding(query, binding_alias) do
      {join_expr, _} when is_struct(join_expr, Ecto.Query.JoinExpr) ->
        lookup_join_source(join_expr, query)

      {%{source: source} = _from_expr, _binding_position} ->
        source
    end
  end

  defp lookup_join_source(
         %{assoc: {0, assoc_key}} = join_expr,
         %{from: from_expr} = query
       ) do
    if has_subquery?(from_expr) do
      inner_query = get_inner_query(query)
      lookup_join_source(join_expr, inner_query)
    else
      with {_, parent_schema} <- get_source(from_expr) do
        {nil, SchemaHelpers.fetch_schema_assoc_module!(parent_schema, assoc_key)}
      end
    end
  end

  defp lookup_join_source(
         %{assoc: {binding_position, assoc_key}} = join_expr,
         %{from: from_expr, joins: joins} = query
       ) do
    case get_in(joins, [Access.at(binding_position)]) do
      nil ->
        if has_subquery?(from_expr) do
          inner_query = get_inner_query(query)
          lookup_join_source(join_expr, inner_query)
        else
          raise ArgumentError,
                """
                binding for association #{inspect(assoc_key)} not found at position #{binding_position} in query.

                query:

                #{inspect(query, pretty: true)}
                """
        end

      %{assoc: {^binding_position, ^assoc_key}} = _join_expr ->
        with {_, parent_schema} <-
               joins
               |> get_in([Access.at!(binding_position - 1)])
               |> lookup_join_source(query) do
          {nil, SchemaHelpers.fetch_schema_assoc_module!(parent_schema, assoc_key)}
        end

      %{source: {_, parent_schema}} = _parent_join_expr ->
        assoc = parent_schema.__schema__(:association, assoc_key)

        if Map.has_key?(assoc, :related) do
          {nil, assoc.related}
        else
          raise ArgumentError,
                """
                Expected a direct association with a `:related` key, but got
                an association that does not support direct Ecto operations.

                This likely happens when using a `:through` association,
                which cannot be used with functions like `put_assoc` or
                `cast_assoc`.

                Supported associations include: `belongs_to`, `has_one`, and `has_many`.

                key:

                #{inspect(assoc_key)}

                association:

                #{inspect(assoc, pretty: true)}

                query:

                #{inspect(query, pretty: true)}
                """
        end

      parent_join_expr ->
        with {_, parent_schema} <- lookup_join_source(parent_join_expr, query) do
          {nil, SchemaHelpers.fetch_schema_assoc_module!(parent_schema, assoc_key)}
        end
    end
  end

  defp lookup_join_source(%{source: source} = _join_expr, _query) do
    get_source(source)
  end

  @doc """
  Looks up a binding in the query using its alias and returns the expression and
  its position.

  If `binding_alias` is `nil` this function will always return the base from
  expression of the given `query`.
  """
  def get_binding(query, binding_alias) when is_struct(query, Ecto.Query) do
    case lookup_binding(query, 0, binding_alias) do
      nil ->
        raise ArgumentError,
              """
              binding not found in query.

              alias:

              #{inspect(binding_alias)}

              query:

              #{inspect(query)}
              """

      {from_expr, binding_position} when is_struct(from_expr, Ecto.Query.FromExpr) ->
        {get_base_expr(from_expr), binding_position}

      val ->
        val
    end
  end

  def get_binding(query_source, binding_alias) do
    query_source
    |> to_query()
    |> get_binding(binding_alias)
  end

  defp lookup_binding(%{from: from_expr, joins: joins} = query, pos, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      {get_base_expr(from_expr), 0}
    else
      with nil <- lookup_binding(from_expr, pos, binding_alias) do
        lookup_binding(joins, pos, binding_alias)
      end
    end
  end

  defp lookup_binding(%{query: query} = subquery, pos, binding_alias)
       when is_struct(subquery, Ecto.SubQuery) do
    lookup_binding(query, pos, binding_alias)
  end

  defp lookup_binding(%{as: as, source: source} = join_expr, pos, binding_alias)
       when is_struct(join_expr, Ecto.Query.JoinExpr) do
    if as === binding_alias do
      {join_expr, pos}
    else
      lookup_binding(source, pos, binding_alias)
    end
  end

  defp lookup_binding(%{as: as, source: source} = from_expr, _pos, binding_alias)
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    if as === binding_alias do
      {from_expr, 0}
    else
      lookup_binding(source, 0, binding_alias)
    end
  end

  defp lookup_binding([], _pos, _binding_alias), do: nil

  defp lookup_binding([join_expr | joins], pos, binding_alias) do
    with nil <- lookup_binding(join_expr, pos + 1, binding_alias) do
      lookup_binding(joins, pos + 1, binding_alias)
    end
  end

  defp lookup_binding(_, _, _), do: nil

  @doc """
  Returns the root binding expression that defines the query’s data source.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in {"posts", EctoShorts.Schemas.Post}, where: p.published == true
      ...> EctoShorts.CommonQuery.get_base_expr(query)
  """
  @spec get_base_expr(query() | subquery() | from_expr()) :: from_expr()
  def get_base_expr(query_or_expr) do
    case lookup_base_expr(query_or_expr) || query_or_expr do
      %{source: {_, _}} = base_expr ->
        base_expr

      %{source: source} = base_expr when is_binary(source) ->
        base_expr

      expr ->
        raise ArgumentError,
              """
              Expected a query, `from` or `join` expression with a `:source` value of type
              `{binary() | nil, module() | nil}` or a database table name as a binary.

              got:

              #{inspect(expr, pretty: true)}
              """
    end
  end

  defp lookup_base_expr(%{source: {_, _}} = expr), do: expr
  defp lookup_base_expr(%{source: source} = expr) when is_binary(source), do: expr
  defp lookup_base_expr(%{source: source}), do: lookup_base_expr(source)
  defp lookup_base_expr(%{query: query}), do: lookup_base_expr(query)
  defp lookup_base_expr(%{from: from_expr}), do: lookup_base_expr(from_expr)
  defp lookup_base_expr(_), do: nil
end
