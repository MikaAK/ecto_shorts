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
    with nil <- extract_source(query_or_expr) do
      raise ArgumentError, "source not found, got: #{inspect(query_or_expr)}"
    end
  end

  defp extract_source(%{from: from_expr}), do: extract_source(from_expr)
  defp extract_source(%{query: query}), do: extract_source(query)
  defp extract_source(%{source: source}), do: extract_source(source)
  defp extract_source({_, _} = source), do: source
  defp extract_source(source) when is_binary(source), do: source
  defp extract_source(_), do: nil

  @doc """
  Returns the `source` of a binding in the given `query`.
  """
  def get_binding_source(query, binding_alias) do
    with nil <- extract_binding_source(query, binding_alias) do
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

  defp extract_binding_source(query, binding_alias) do
    case get_binding(query, binding_alias) do
      {join_expr, _} when is_struct(join_expr, Ecto.Query.JoinExpr) ->
        get_join_expr_source(join_expr, query)

      {%{source: source} = _from_expr, _binding_position} ->
        source
    end
  end

  defp get_join_expr_source(
         %{assoc: {binding_position, key}} = join_expr,
         %{from: from_expr, joins: joins} = query
       ) do
    case get_in(joins, [Access.at(binding_position)]) do
      nil ->
        if has_subquery?(from_expr) do
          inner_query = get_inner_query(query)
          get_join_expr_source(join_expr, inner_query)
        else
          raise_parent_assoc_not_found!(binding_position, key, query)
        end

      %{assoc: {^binding_position, ^key}} = _join_expr ->
        if binding_position === 0 do
          # self referencing join which has the binding position 0 meaning its the first
          # join expr in the query so the parent is the base from expression
          if has_subquery?(from_expr) do
            inner_query = get_inner_query(query)
            get_join_expr_source(join_expr, inner_query)
          else
            from_expr
            |> get_source()
            |> resolve_schema_source_assoc(key)
          end
        else
          # binding position is not 0 and this is self referenced which means that the binding
          # we are looking for is the one before this. We need to resolve the parent schema
          # here first to find the association.
          joins
          |> get_in([Access.at!(binding_position - 1)])
          |> get_join_expr_source(query)
          |> resolve_schema_source_assoc(key)
        end

      %{assoc: {_, _}} = join_expr ->
        # not a self referenced join expression
        join_expr
        |> get_join_expr_source(query)
        |> resolve_schema_source_assoc(key)

      %{source: {_, parent_schema}} when not is_nil(parent_schema) ->
        assoc = parent_schema.__schema__(:association, key)

        if related_assoc?(assoc) do
          {nil, assoc.related}
        else
          raise_not_related_assoc!(query, key, assoc)
        end
    end
  end

  defp get_join_expr_source(%{source: source} = _join_expr, _query) do
    get_source(source)
  end

  defp get_join_expr_source(_, _) do
    nil
  end

  defp resolve_schema_source_assoc({_, parent_schema}, key) when is_atom(parent_schema) do
    {nil, SchemaHelpers.fetch_schema_association_module!(parent_schema, key)}
  end

  defp resolve_schema_source_assoc(term, _key) do
    term
  end

  defp raise_parent_assoc_not_found!(binding_position, key, query) do
    raise ArgumentError,
          """
          association binding #{inspect(key)} not found at position #{binding_position} in query.

          query:

          #{inspect(query, pretty: true)}
          """
  end

  defp related_assoc?(%{related: _}), do: true
  defp related_assoc?(_), do: false

  defp raise_not_related_assoc!(query, key, assoc) do
    raise ArgumentError,
          """
          Expected a direct association with a `:related` key, but got
          an association that does not support direct Ecto operations.

          This likely happens when using a `:through` association,
          which cannot be used with functions like `put_assoc` or
          `cast_assoc`.

          Supported associations include: `belongs_to`, `has_one`, and `has_many`.

          key:

          #{inspect(key)}

          association:

          #{inspect(assoc, pretty: true)}

          query:

          #{inspect(query, pretty: true)}
          """
  end

  @doc """
  Looks up a binding in the query using its alias and returns the expression and
  its position.

  If `binding_alias` is `nil` this function will always return the base from
  expression of the given `query`.
  """
  def get_binding(query, binding_alias) when is_struct(query, Ecto.Query) do
    case extract_binding(query, 0, binding_alias) do
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

  defp extract_binding(%{from: from_expr, joins: joins} = query, pos, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      {get_base_expr(from_expr), 0}
    else
      with nil <- extract_binding(from_expr, pos, binding_alias) do
        extract_binding(joins, pos, binding_alias)
      end
    end
  end

  defp extract_binding(%{query: query} = subquery, pos, binding_alias)
       when is_struct(subquery, Ecto.SubQuery) do
    extract_binding(query, pos, binding_alias)
  end

  defp extract_binding(%{as: as, source: source} = join_expr, pos, binding_alias)
       when is_struct(join_expr, Ecto.Query.JoinExpr) do
    if as === binding_alias do
      {join_expr, pos}
    else
      extract_binding(source, pos, binding_alias)
    end
  end

  defp extract_binding(%{as: as, source: source} = from_expr, _pos, binding_alias)
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    if as === binding_alias do
      {from_expr, 0}
    else
      extract_binding(source, 0, binding_alias)
    end
  end

  defp extract_binding([], _pos, _binding_alias), do: nil

  defp extract_binding([join_expr | joins], pos, binding_alias) do
    with nil <- extract_binding(join_expr, pos + 1, binding_alias) do
      extract_binding(joins, pos + 1, binding_alias)
    end
  end

  defp extract_binding(_, _, _), do: nil

  @doc """
  Returns the root binding expression that defines the query’s data source.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in {"posts", EctoShorts.Schemas.Post}, where: p.published == true
      ...> EctoShorts.CommonQuery.get_base_expr(query)
  """
  @spec get_base_expr(query() | subquery() | from_expr()) :: from_expr()
  def get_base_expr(query_or_expr) do
    case extract_base_from_expr(query_or_expr) || query_or_expr do
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

  defp extract_base_from_expr(%{source: {_, _}} = expr), do: expr
  defp extract_base_from_expr(%{source: source} = expr) when is_binary(source), do: expr
  defp extract_base_from_expr(%{source: source}), do: extract_base_from_expr(source)
  defp extract_base_from_expr(%{query: query}), do: extract_base_from_expr(query)
  defp extract_base_from_expr(%{from: from_expr}), do: extract_base_from_expr(from_expr)
  defp extract_base_from_expr(_), do: nil
end
