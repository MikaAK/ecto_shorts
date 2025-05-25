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
  def get_source(%{from: from_expr}), do: get_source(from_expr)
  def get_source(%{query: query}), do: get_source(query)
  def get_source(%{source: source}), do: get_source(source)
  def get_source({_, _} = source), do: source
  def get_source(source) when is_binary(source), do: source
  def get_source(_), do: nil

  def validate_query_binding_schema_source!(query) when is_struct(query, Ecto.Query) do
    case get_source(query) do
      {source, schema} when is_atom(schema) and not is_nil(schema) ->
        {source, schema}

      term ->
        raise ArgumentError,
              """
              Expected a source tuple with a schema.

              A valid source should be a schema or a tuple in the form of
              {source, schema}, where schema is a module.

              got:

              #{inspect(term)}
              """
    end
  end

  def validate_query_binding_schema_source(query) when is_struct(query, Ecto.Query) do
    case get_source(query) do
      {source, schema} when is_atom(schema) and not is_nil(schema) ->
        {:ok, {source, schema}}

      term ->
        {:error, term}
    end
  end

  @doc """
  Similar to `validate_query_binding_schema_source/2` and raises an error if the source is
  not a tuple with a schema.
  """
  def validate_query_binding_schema_source!(query, binding_alias) do
    case get_query_binding_source(query, binding_alias) do
      {source, schema} when is_atom(schema) and not is_nil(schema) ->
        {source, schema}

      term ->
        raise ArgumentError,
              """
              Expected a source tuple with a schema.

              A valid source should be a schema or a tuple in the form of
              {source, schema}, where schema is a module.

              got:

              #{inspect(term)}
              """
    end
  end

  @doc """
  Validates that the source associated with a given binding is a tuple
  containing a table name and a schema module.

  Returns a tuple `{source, schema}` if the source is a tuple with a
  schema module otherwise `{:error, term}`
  """
  def validate_query_binding_schema_source(query, nil) do
    validate_query_binding_schema_source(query)
  end

  def validate_query_binding_schema_source(query, binding_alias) do
    case get_query_binding_source(query, binding_alias) do
      {source, schema} when is_atom(schema) and not is_nil(schema) ->
        {:ok, {source, schema}}

      term ->
        {:error, term}
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
      ...> EctoShorts.CommonQuery.get_query_binding_source(query, :author)
      {nil, EctoShorts.Schemas.User}
  """
  @spec get_query_binding_source(query(), binding_alias()) :: expr_source() | nil
  def get_query_binding_source(query, binding_alias) when is_struct(query, Ecto.Query) do
    case get_query_binding(query, binding_alias) do
      nil ->
        nil

      {join_expr, _} when is_struct(join_expr, Ecto.Query.JoinExpr) ->
        get_join_expr_source(join_expr, query)

      {%{source: source} = _expr, _} ->
        source
    end
  end

  defp get_join_expr_source(
         %{assoc: {parent_binding_position, parent_key}} = join_expr,
         %{from: from_expr, joins: joins} = query
       ) do
    if parent_binding_position === 0 do
      with {_, parent_schema} when is_atom(parent_schema) and not is_nil(parent_schema) <-
             get_source(from_expr) do
        {nil, SchemaHelpers.fetch_schema_association_module!(parent_schema, parent_key)}
      end
    else
      case Enum.at(joins, parent_binding_position) do
        nil ->
          # If the parent binding for the join expr does not exist in the
          # top level of the query if might exist in a subquery so we
          # have to continue searching.
          if has_subquery?(from_expr) do
            get_join_expr_source(join_expr, get_inner_query(query))
          else
            raise ArgumentError,
                  """
                  binding not found in query at position #{parent_binding_position}.

                  query:

                  #{inspect(query, pretty: true)}
                  """
          end

        %{assoc: {^parent_binding_position, ^parent_key}} ->
          # If the join expr's assoc refers to the same binding position
          # it's at, it means the association is actually relative to the `from`
          # source so we terminate here to prevent infinite recursion.
          with {_, parent_schema} when is_atom(parent_schema) and not is_nil(parent_schema) <-
                 get_source(from_expr) do
            {nil, SchemaHelpers.fetch_schema_association_module!(parent_schema, parent_key)}
          end

        %{source: {_, parent_schema}} = _parent_join_expr ->
          assoc = parent_schema.__schema__(:association, parent_key)

          assoc_schema =
            if assoc_has_related_key?(assoc) do
              assoc.related
            else
              raise_not_related_assoc!(query, parent_key, assoc)
            end

          {nil, assoc_schema}

        parent_join_expr ->
          {_, parent_schema} = get_join_expr_source(parent_join_expr, query)

          assoc = parent_schema.__schema__(:association, parent_key)

          assoc_schema =
            if assoc_has_related_key?(assoc) do
              assoc.related
            else
              raise_not_related_assoc!(query, parent_key, assoc)
            end

          {nil, assoc_schema}
      end
    end
  end

  defp get_join_expr_source(%{source: source} = _join_expr, _query) do
    get_source(source)
  end

  defp assoc_has_related_key?(%{related: _}), do: true
  defp assoc_has_related_key?(_), do: false

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
  @spec get_query_binding(query(), binding_alias()) ::
          {from_expr() | join_expr(), non_neg_integer()} | nil
  def get_query_binding(query, binding_alias) when is_struct(query, Ecto.Query) do
    query
    |> extract_binding_expr(0, binding_alias)
    |> ensure_base_from_expr()
  end

  defp ensure_base_from_expr({from_expr, binding_position})
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    {get_query_base_expr(from_expr), binding_position}
  end

  defp ensure_base_from_expr(val) do
    val
  end

  defp extract_binding_expr(%{from: from_expr, joins: join_exprs} = query, pos, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      {get_query_base_expr(from_expr), 0}
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

  @doc """
  Returns the root binding expression that defines the query’s data source.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in {"posts", EctoShorts.Schemas.Post}, where: p.published == true
      ...> EctoShorts.CommonQuery.get_query_base_expr(query)
  """
  @spec get_query_base_expr(query() | subquery() | from_expr()) :: from_expr()
  def get_query_base_expr(query_or_expr) do
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
