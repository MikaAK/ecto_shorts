defmodule EctoShorts.CommonQuery do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Introspects `Ecto.Query` structures at runtime.

  Use this module when you need to inspect a query to find out what table
  it queries, what bindings it has, or what schema a specific binding uses.
  This is useful when building dynamic query composers, debugging query
  construction, or implementing query middleware.

  ## Inspect query structure

  Extract the source from a query:

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post
      ...> EctoShorts.CommonQuery.get_query_source(q)
      {"posts", EctoShorts.Schema.Post}

  Count the bindings in a query:

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post, join: c in assoc(p, :comments)
      ...> EctoShorts.CommonQuery.query_binding_count(q)
      2

  Get the source for a specific binding:

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post, as: :post, join: c in assoc(p, :comments), as: :comment
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, :comment)
      {nil, EctoShorts.Schema.Comment}

  ## When to use query introspection

  Use this module when you need to:

  * **Build dynamic filters** - determine which schema a binding uses so you
    can validate field names or resolve field types.
  * **Implement query middleware** - inspect the query structure before or
    after applying transformations.
  * **Debug query construction** - verify that joins were added correctly
    and bindings point to the expected schemas.
  * **Validate binding limits** - check that the query does not exceed the
    configured maximum binding count.
  * **Resolve association schemas** - find out which schema an `assoc/2`
    join points to without manually traversing the association tree.

  ## Bindings deep dive

  Ecto queries use bindings to reference tables in the query. The root
  `from` clause creates binding `1`, and each `join` adds a new binding
  (`2`, `3`, etc.).

  ### Named bindings

  Named bindings use the `:as` option to assign an atom identifier:

      import Ecto.Query

      q = from p in Post, as: :post,
            join: c in assoc(p, :comments), as: :comment

  You can reference these bindings by name:

      EctoShorts.CommonQuery.get_query_binding_source(q, :post)
      # {"posts", Post}

      EctoShorts.CommonQuery.get_query_binding_source(q, :comment)
      # {nil, Comment}

  ### Positional bindings

  Positional bindings use integers where `1` is the root `from` and each
  join increments the position:

      import Ecto.Query

      q = from p in Post,
            join: c in assoc(p, :comments),
            join: a in assoc(p, :author)

      EctoShorts.CommonQuery.get_query_binding_source(q, 1)
      # {"posts", Post}

      EctoShorts.CommonQuery.get_query_binding_source(q, 2)
      # {nil, Comment}

      EctoShorts.CommonQuery.get_query_binding_source(q, 3)
      # {nil, Author}

  ### Negative positions

  Negative positions count backwards from the end, where `-1` is the last
  binding:

      EctoShorts.CommonQuery.get_query_binding_source(q, -1)
      # {nil, Author}

  ## Source tuples

  Ecto represents sources as `{source, schema}` tuples:

  | Tuple                  | Meaning                                      |
  |------------------------|----------------------------------------------|
  | `{"posts", Post}`      | Table name `"posts"` with schema `Post`      |
  | `{"posts", nil}`       | Table name `"posts"` without a schema        |
  | `{nil, Post}`          | Schema `Post` (table name from schema)       |

  Functions in this module return `nil` when a source or binding cannot be
  resolved.

  ## Association joins

  When a binding points to an association join (`assoc/2`), this module
  resolves the related schema from the parent binding:

      import Ecto.Query

      q = from p in Post, as: :post,
            join: c in assoc(p, :comments), as: :comment

      EctoShorts.CommonQuery.get_query_binding_source(q, :comment)
      # {nil, Comment}

  The table name is `nil` because association joins do not specify an
  explicit table name - Ecto infers it from the schema.

  ## Subquery handling

  When a query contains a subquery in the `from` clause, this module
  traverses into the subquery to find the root source:

      import Ecto.Query

      inner = from p in Post, where: p.published == true
      outer = from p in subquery(inner), select: p.id

      EctoShorts.CommonQuery.get_query_source(outer)
      # {"posts", Post}

  ## Common patterns

  **Pattern 1: Validate binding exists**

  Check that a binding exists before using it:

      def apply_filter(query, binding_name, field, value) do
        source = EctoShorts.CommonQuery.get_query_binding_source(query, binding_name)

        if source do
          # Binding exists, apply filter
        else
          # Binding does not exist, skip or raise
        end
      end

  **Pattern 2: Get schema for field validation**

  Extract the schema to validate that a field exists:

      def validate_field(query, binding_name, field) do
        case EctoShorts.CommonQuery.get_query_binding_source(query, binding_name) do
          {_, schema} when schema !== nil ->
            field in schema.__schema__(:fields)

          _ ->
            false
        end
      end

  **Pattern 3: Check binding limit**

  Ensure the query does not exceed the maximum binding count:

      def check_binding_limit(query) do
        count = EctoShorts.CommonQuery.query_binding_count(query)
        max = EctoShorts.Config.max_positional_bindings()

        if count > max do
          raise "Query has \#{count} bindings but max is \#{max}"
        end
      end

  **Pattern 4: Resolve association schema**

  Find the schema for an association without manually traversing:

      import Ecto.Query

      q = from p in Post, join: c in assoc(p, :comments), as: :comment

      {_, schema} = EctoShorts.CommonQuery.get_query_binding_source(q, :comment)
      # schema = Comment

  ## Troubleshooting

  **Problem:** `get_query_binding_source/2` returns `nil` for a named binding.

  **Solution:** Verify the binding name matches exactly. Binding names are
  atoms, so `:post` and `"post"` are different.

  **Problem:** Positional binding returns `nil`.

  **Solution:** Check that the position is within range. Use
  `query_binding_count/1` to see how many bindings exist.

  **Problem:** Association join returns `{nil, nil}` instead of a schema.

  **Solution:** The parent binding may not have a schema. Association joins
  require the parent binding to have a schema module so the association can
  be resolved.

  See also `EctoShorts.CommonSchema`, `EctoShorts.CommonFilters`, and
  `EctoShorts.Config.max_positional_bindings/0`.
  """

  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @doc """
  Returns the query prefix for the given queryable, or `nil` if none is set.

  The prefix corresponds to the PostgreSQL schema (or equivalent) set via
  `Ecto.put_meta/2` or configured in the schema module.

  ## Examples

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.PostHasSchemaPrefix
      ...> EctoShorts.CommonQuery.get_query_prefix(q)
      "custom_schema_prefix"

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post
      ...> EctoShorts.CommonQuery.get_query_prefix(q)
      nil

  See also `get_query_source/1` and `EctoShorts.CommonSchema.get_schema_prefix/1`.
  """
  def get_query_prefix(queryable) do
    %{prefix: prefix} = queryable |> to_query!() |> get_query_source_expr()
    prefix
  end

  @doc """
  Returns the root source tuple for the given query.

  Traverses composed queries and subqueries until it reaches an expression
  with a concrete `{source, schema}` source tuple. Returns `nil` when the
  source cannot be resolved.

  ## Examples

      iex> import Ecto.Query
      ...> q = from p in "users"
      ...> EctoShorts.CommonQuery.get_query_source(q)
      {"users", nil}

      iex> import Ecto.Query
      ...> q = EctoShorts.Schema.User
      ...> EctoShorts.CommonQuery.get_query_source(q)
      {"users", EctoShorts.Schema.User}

      iex> import Ecto.Query
      ...> q = from {"custom_source", EctoShorts.Schema.User}
      ...> EctoShorts.CommonQuery.get_query_source(q)
      {"custom_source", EctoShorts.Schema.User}

  See also `get_query_prefix/1` and `get_query_binding_source/2`.
  """
  def get_query_source(queryable) do
    %{source: source} = queryable |> to_query!() |> get_query_source_expr()
    source
  end

  defp get_query_source_expr(%{query: query} = _subquery) do
    get_query_source_expr(query)
  end

  defp get_query_source_expr(%{from: from_expr} = _query) do
    get_query_source_expr(from_expr)
  end

  defp get_query_source_expr(%{source: {_, _}} = from_or_join_expr) do
    from_or_join_expr
  end

  defp get_query_source_expr(%{source: source}) do
    get_query_source_expr(source)
  end

  @doc """
  Returns the number of bindings in the given query.

  Counts the root `from` binding as `1`, plus one for each join. Useful
  when building dynamic queries that need to stay within the binding limit
  configured via `:max_positional_bindings`.

  ## Examples

      iex> EctoShorts.CommonQuery.query_binding_count(EctoShorts.Schema.Post)
      1

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post, join: c in assoc(p, :comments), as: :comment
      ...> EctoShorts.CommonQuery.query_binding_count(q)
      2

      iex> import Ecto.Query
      ...> q = from p in EctoShorts.Schema.Post,
      ...>       join: c in assoc(p, :comments),
      ...>       join: a in assoc(p, :author)
      ...> EctoShorts.CommonQuery.query_binding_count(q)
      3

  See also `get_query_binding_source/2` and `EctoShorts.Config.max_positional_bindings/0`.
  """
  def query_binding_count(queryable) do
    query = to_query!(queryable)
    1 + length(query.joins)
  end

  @doc """
  Returns the source tuple for the given binding.

  `binding_alias_or_pos` can be a named binding atom (matching the `as:` key
  in the query) or an integer position (`1` for the root `from`, `2` for the
  first join, etc.).

  When the binding points to an association join (`assoc/2`), this function
  resolves the related schema from the parent binding and returns
  `{nil, RelatedSchema}`. Returns `nil` when the binding cannot be resolved.

  ## Examples

      iex> import Ecto.Query
      ...> q = from u in "users", as: :user
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, :user)
      {"users", nil}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User, as: :user
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, :user)
      {"users", EctoShorts.Schema.User}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User, as: :user, join: p in assoc(u, :posts), as: :post
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, :post)
      {nil, EctoShorts.Schema.Post}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User, as: :user, join: p in assoc(u, :posts), as: :post
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, 1)
      {"users", EctoShorts.Schema.User}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User, as: :user, join: p in assoc(u, :posts), as: :post
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, 2)
      {nil, EctoShorts.Schema.Post}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User, join: p in assoc(u, :posts)
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, -1)
      {nil, EctoShorts.Schema.Post}

      iex> import Ecto.Query
      ...> q = from u in EctoShorts.Schema.User
      ...> EctoShorts.CommonQuery.get_query_binding_source(q, :nonexistent)
      nil

  Position `0` is not a valid binding position and returns `nil`. Positions
  are 1-based: `1` is the root `from`, `2` is the first join, and so on.
  Negative positions index from the end of the join list (`-1` is the last join).

  See also `query_binding_count/1` and `get_query_source/1`.
  """
  def get_query_binding_source(queryable, binding_alias_or_pos) do
    case get_binding_expr(queryable, binding_alias_or_pos) do
      %Ecto.Query.JoinExpr{} = join_expr ->
        get_join_expr_source(queryable, join_expr)

      %Ecto.Query.FromExpr{source: source} ->
        source

      other ->
        other
    end
  end

  defp get_join_expr_source(%{from: from_expr}, %Ecto.Query.JoinExpr{assoc: {0, assoc_key}}) do
    case get_query_source(from_expr) do
      {_, nil} -> nil
      {_, schema} -> {nil, SchemaHelpers.get_related_schema(schema, assoc_key)}
    end
  end

  defp get_join_expr_source(
         %{joins: joins} = query,
         %Ecto.Query.JoinExpr{assoc: {index, assoc_key}} = join_expr
       ) do
    case get_in(joins, [Access.at(index)]) do
      %Ecto.Query.JoinExpr{assoc: {^index, ^assoc_key}} ->
        ref_join_expr = get_in(joins, [Access.at!(index - 1)])

        {_, schema} = get_join_expr_source(query, ref_join_expr)
        {nil, SchemaHelpers.get_related_schema(schema, assoc_key)}

      _ ->
        query
        |> get_inner_query()
        |> get_join_expr_source(join_expr)
    end
  end

  defp get_join_expr_source(_query, join_expr), do: get_query_source(join_expr)

  defp get_inner_query(%Ecto.Query{from: %{source: %{query: query}}}), do: query

  defp get_binding_expr(%Ecto.Query{} = query, pos) when is_integer(pos) do
    binding_at(query, pos)
  end

  defp get_binding_expr(%Ecto.Query{} = query, binding_alias) do
    binding_for_alias(query, binding_alias)
  end

  defp get_binding_expr(source, binding_alias_or_pos) do
    source
    |> Queryable.to_query()
    |> get_binding_expr(binding_alias_or_pos)
  end

  defp binding_at(%Ecto.Query{from: from_expr} = _query, 1) do
    from_expr
  end

  defp binding_at(%Ecto.Query{joins: joins} = _query, pos) when pos < 0 do
    Enum.at(joins, pos)
  end

  defp binding_at(%Ecto.Query{joins: joins} = _query, pos) when pos > 1 do
    Enum.at(joins, pos - 2)
  end

  defp binding_for_alias(query, binding_alias) do
    case get_named_binding_expr(query, binding_alias) do
      %Ecto.Query.FromExpr{} = from_expr ->
        get_query_source_expr(from_expr)

      %Ecto.Query.JoinExpr{} = join_expr ->
        join_expr

      _ ->
        nil
    end
  end

  defp get_named_binding_expr(%{from: from_expr, joins: joins} = query, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      get_query_source_expr(from_expr)
    else
      with nil <- get_named_binding_expr(from_expr, binding_alias) do
        get_named_binding_expr(joins, binding_alias)
      end
    end
  end

  defp get_named_binding_expr(%Ecto.SubQuery{query: query}, binding_alias) do
    get_named_binding_expr(query, binding_alias)
  end

  defp get_named_binding_expr(
         %Ecto.Query.JoinExpr{as: binding_alias, source: _} = join_expr,
         binding_alias
       ),
       do: join_expr

  defp get_named_binding_expr(%Ecto.Query.JoinExpr{source: source}, binding_alias),
    do: get_named_binding_expr(source, binding_alias)

  defp get_named_binding_expr(
         %Ecto.Query.FromExpr{as: binding_alias, source: _} = from_expr,
         binding_alias
       ),
       do: from_expr

  defp get_named_binding_expr(%Ecto.Query.FromExpr{source: source}, binding_alias),
    do: get_named_binding_expr(source, binding_alias)

  defp get_named_binding_expr([], _binding_alias), do: nil

  defp get_named_binding_expr([join_expr | joins], binding_alias) do
    with nil <- get_named_binding_expr(join_expr, binding_alias) do
      get_named_binding_expr(joins, binding_alias)
    end
  end

  defp get_named_binding_expr(_, _), do: nil

  defp to_query!(queryable) do
    case queryable do
      %_{} = query ->
        query

      other when is_atom(other) or is_binary(other) or is_tuple(other) ->
        Queryable.to_query(other)

      term ->
        raise ArgumentError, "expected a queryable, got: #{inspect(term)}"
    end
  end
end
