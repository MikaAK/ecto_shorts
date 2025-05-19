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

      EctoShorts.CommonQueries.get_from_expr(query)
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

      EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :schema)
      EctoShorts.Schemas.Post

  To get the source name (the table name):

      EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :source)
      "posts"

  This simplifies working with joins, nested queries, or association
  based filters.
  """

  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @type from_expr :: %{
          optional(:__struct__) => Ecto.Query.FromExpr,
          optional(atom()) => any(),
          as: any(),
          prefix: any(),
          params: any(),
          source: any()
        }

  @type join_expr :: %{
          optional(:__struct__) => Ecto.Query.JoinExpr,
          optional(atom()) => any(),
          as: any(),
          assoc: any(),
          on: any(),
          prefix: any(),
          params: any(),
          qual: any(),
          source: any()
        }

  @type subquery :: Ecto.SubQuery.t()
  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type query_source :: query() | sourceable()
  @type query_node :: query() | subquery() | from_expr() | join_expr()
  @type query_input :: query_node() | sourceable() | any()
  @type binding_expr :: from_expr() | join_expr() | {join_expr(), from_expr()} | nil
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

  @doc """
  Returns the root `from` expression from a query, subquery, or schema.

  Ecto queries can be composed using different layers like schemas,
  subqueries, or pre-built query structs. This function walks through
  any of those forms and returns the final Ecto Query from expression
  struct that describes the base table and schema.

  In an Ecto Query from expression struct, the `:source` field can be
  one of the following types:

  1. A tuple of `{schema_source(), schema_module()}` tuple:

    This is the most common form:

        {"posts", EctoShorts.Schemas.Post}

    The `schema_source` represents the database table name (e.g. "posts")
    and can be `nil`.

    The second element is a module that implements the `Ecto.Queryable`
    protocol (this is usually the module where you define `use Ecto.Schema`).

    This format appears when you build queries directly from schema modules
    or explicitly specify a source.

  2. An Ecto.Query Struct:

    This can happen when you pass a base query directly into another
    from expression:

        query = from p in Post, where: p.published == true
        outer = from p in query

    Here, `outer.from.source` will hold the inner `Ecto.Query` struct.

  3. An Ecto SubQuery Struct:

  This occurs when you wrap a query with subquery/1:

      inner = from p in Post, where: p.published == true
      outer = from p in subquery(inner), as: :post

  In this case, `outer.from.source` will be a `Ecto.SubQuery` struct.
  """
  @spec get_from_expr(query_input()) :: from_expr()
  def get_from_expr(%{source: {_, _}} = from_expr), do: from_expr
  def get_from_expr(%{source: source}), do: get_from_expr(source)
  def get_from_expr(%{from: from_expr}), do: get_from_expr(from_expr)
  def get_from_expr(%{query: query} = _subquery), do: get_from_expr(query)
  def get_from_expr(query_source), do: query_source |> to_query() |> get_from_expr()

  @doc """
  Fetches the source and schema module for a named binding in a query.

  This is similar to `find_binding_expr_source_and_schema/2`, but raises an
  error if the named binding cannot be found instead of returning `nil`.

  It’s a useful alternative when you want to ensure the binding exists
  and don’t want to manually handle `nil` or `:error` cases.

  ## Examples

      iex> import Ecto.Query
      ...> query =
      ...>   from p in EctoShorts.Schemas.Post,
      ...>     as: :post,
      ...>     join: assoc(p, :comments),
      ...>     as: :comments,
      ...>     on: true
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema!(query, :comments)
      {"comments", EctoShorts.Schemas.Comment}
  """
  @spec get_from_expr(query_input(), key()) :: any() | nil
  def get_from_expr(query, key) do
    with from_expr when is_map(from_expr) <- get_from_expr(query) do
      Map.get(from_expr, key)
    end
  end

  @doc """
  Checks if a query is ultimately built on top of a subquery.

  When working with Ecto, you can create queries using a schema, another query,
  or a subquery. This function helps you figure out if a given query is backed
  by a subquery.

  It works by looking at the source of the query and recursively following
  any nested queries until it reaches the base. If that base is a subquery,
  it returns `true`. Otherwise, it returns `false`.

  ## Examples

      # When using a schema directly

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> EctoShorts.CommonQueries.has_source_subquery?(query)
      false

      # When using a subquery as the base

      iex> import Ecto.Query
      ...> base = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> query = from p in subquery(base), as: :post
      ...> EctoShorts.CommonQueries.has_source_subquery?(query)
      true

      ## When wrapping a subquery multiple times

      iex> import Ecto.Query
      ...> first_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> second_query = from p in subquery(first_query), as: :post
      ...> third_query = from p in second_query, where: p.id in [1, 2, 3]
      ...> EctoShorts.CommonQueries.has_source_subquery?(third_query)
      true

      # When nesting queries without using `subquery/1`

      iex> import Ecto.Query
      ...> base = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> query = from p in base, where: p.id in [1, 2, 3]
      ...> EctoShorts.CommonQueries.has_source_subquery?(query)
      false
  """
  @spec has_source_subquery?(query_node()) :: boolean()
  def has_source_subquery?(%{source: %{query: _}}), do: true
  def has_source_subquery?(%{source: {_, _}}), do: false
  def has_source_subquery?(%{source: source}), do: has_source_subquery?(source)
  def has_source_subquery?(%{from: from}), do: has_source_subquery?(from)
  def has_source_subquery?(%{query: query}), do: has_source_subquery?(query)
  def has_source_subquery?(_), do: false

  @doc """
  Looks up a value from the subquery used as the source for the given query.

  This function first checks if the query is based on a subquery (using
  `get_source_subquery/1`), and if so, retrieves the value for the given
  `key` from that subquery.

  Returns `nil` if the query does not use a subquery as its source.

  ## Examples

      # Access the original `:from` clause of the subquery
      iex> import Ecto.Query
      ...> inner_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> outer_query = from p in subquery(inner_query), as: :post
      ...> EctoShorts.CommonQueries.get_source_subquery(outer_query, :query)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.published == true>
  """
  @spec get_source_subquery(query_node(), key()) :: any() | nil
  def get_source_subquery(query, key) do
    with subquery when is_map(subquery) <- get_source_subquery(query) do
      Map.get(subquery, key)
    end
  end

  @doc """
  Returns the first subquery found in the query's source chain.

  This function checks whether a query or subquery is being used as the
  source of a query (instead of a schema or table). It walks through the
  nested structure of the query to find the original subquery if present.

  It’s useful when you want to introspect deeply nested queries and extract
  the original data source they’re built on top of.

  ## Examples

      # When the source is a schema (not a subquery)
      iex> import Ecto.Query
      ...> EctoShorts.CommonQueries.get_source_subquery(EctoShorts.Schemas.Post)
      nil

      # A query that directly wraps a subquery
      iex> import Ecto.Query
      ...> source_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> outer_query = from p in subquery(source_query), as: :post
      ...> EctoShorts.CommonQueries.get_source_subquery(outer_query)
      subquery(source_query)

      # A query that wraps a subquery inside another query
      iex> import Ecto.Query
      ...> source_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> outer_query = from p in subquery(source_query), as: :post
      ...> final_query = from p in outer_query, where: p.id in [1, 2, 3]
      ...> EctoShorts.CommonQueries.get_source_subquery(final_query)
      subquery(source_query)

      # A deeply nested query containing a subquery
      iex> import Ecto.Query
      ...> base_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> source_query = from p in subquery(base_query), as: :post
      ...> outer_query = from p in subquery(source_query), where: p.id in [1, 2, 3]
      ...> final_query = from p in outer_query, where: p.id in [1, 2, 3]
      ...> EctoShorts.CommonQueries.get_source_subquery(final_query)
      subquery(source_query)
  """
  @spec get_source_subquery(query_node()) :: subquery() | nil
  def get_source_subquery(%{source: {_, _}}), do: nil
  def get_source_subquery(%{source: %{query: _} = subquery}), do: subquery
  def get_source_subquery(%{source: source}), do: get_source_subquery(source)
  def get_source_subquery(%{from: from}), do: get_source_subquery(from)
  def get_source_subquery(%{query: query}), do: get_source_subquery(query)
  def get_source_subquery(_), do: nil

  @doc """
  Fetches the source and schema module for a named binding in a query.

  This is similar to `find_binding_expr_source_and_schema/2`, but raises
  an error if the named binding cannot be found instead of returning `nil`.

  It’s a useful alternative when you want to ensure the binding exists and
  don’t want to manually handle `nil` or `:error` cases.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post, join: assoc(p, :comments), as: :comments, on: true
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema!(query, :comments)
      {"comments", EctoShorts.Schemas.Comment}
  """
  @spec fetch_binding_expr_source_and_schema(
          query_input(),
          binding_alias() | nil
        ) :: source_and_schema()
  def fetch_binding_expr_source_and_schema!(query, binding_alias) do
    with :error <- fetch_binding_expr_source_and_schema(query, binding_alias) do
      raise ArgumentError,
            "named binding alias '#{inspect(binding_alias)}' not found: #{inspect(query)}"
    end
  end

  @doc """
  Fetches the source or schema for a named binding, raising if the binding
  is not found.

  This is a convenience version of `fetch_binding_expr_source_and_schema/2`
  that returns just the `:source` (table name) or the `:schema` (module).

  ## Examples

      # To get the schema module:

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :schema)
      EctoShorts.Schemas.Post

      # To get the source string (like `"comments"`):

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :source)
      "posts"
  """
  @spec fetch_binding_expr_source_and_schema(
          query_input(),
          binding_alias() | nil,
          key()
        ) :: source_and_schema()
  def fetch_binding_expr_source_and_schema!(query, binding_alias, key) do
    with :error <- fetch_binding_expr_source_and_schema(query, binding_alias, key) do
      raise ArgumentError,
            "named binding alias '#{inspect(binding_alias)}' not found: #{inspect(query)}"
    end
  end

  @doc """
  Returns the source and schema for a named binding in the query,
  or `:error` if the binding can’t be found.

  This function is a non-raising version of `fetch_binding_expr_source_and_schema!/2`.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post)
      {"posts", EctoShorts.Schemas.Post}

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :unknown)
      :error
  """
  @spec fetch_binding_expr_source_and_schema(
          query_input(),
          binding_alias() | nil
        ) :: source_and_schema() | :error
  def fetch_binding_expr_source_and_schema(query, binding_alias) do
    with nil <- find_binding_expr_source_and_schema(query, binding_alias) do
      :error
    end
  end

  @doc """
  Returns either the schema module or the table name for a named binding
  in a query. If the binding can’t be found, it returns `:error`.

  This is useful when you want to extract just one part of the binding
  information instead of a full `{source, schema}` tuple.

  The `key` determines what is returned:

    * `:schema` – Returns the module for the schema.

    * `:source` – Returns the table name as a string.

  ## Example

      # Returns the schema module

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :schema)
      EctoShorts.Schemas.Post

      # Returns the database table name string

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonQueries.fetch_binding_expr_source_and_schema(query, :post, :source)
      "posts"
  """
  @spec fetch_binding_expr_source_and_schema(
          query_input(),
          binding_alias() | nil,
          key()
        ) :: source_and_schema() | :error
  def fetch_binding_expr_source_and_schema(query, binding_alias, :source) do
    with {schema_source, _schema_module} <-
           fetch_binding_expr_source_and_schema(query, binding_alias) do
      schema_source
    end
  end

  def fetch_binding_expr_source_and_schema(query, binding_alias, :schema) do
    with {_schema_source, schema_module} <-
           fetch_binding_expr_source_and_schema(query, binding_alias) do
      schema_module
    end
  end

  @doc """
  Finds the source name and schema module for a named binding in a query.

  This function is helpful when you're working with a query that uses named
  bindings (via `as: :name`) and you want to figure out what schema or table
  is associated with that name.

  It supports both top-level bindings and joins, including associations and
  subqueries. If it finds a match, it returns a tuple like
  `{"posts", MyApp.Schema.Post}`. If no match is found, it returns `nil`.

  ## Examples

      # You can use it to find join bindings

      iex> import Ecto.Query
      ...> query =
      ...>   from p in EctoShorts.Schemas.Post,
      ...>     as: :post,
      ...>     join: assoc(p, :comments),
      ...>     as: :comments,
      ...>     on: true
      ...> EctoShorts.CommonQueries.find_binding_expr_source_and_schema(query, :comments)
      {"comments", EctoShorts.Schemas.Comment}

      # You can also use it to find top-level bindings:

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post, where: p.published == true
      ...> EctoShorts.CommonQueries.find_binding_expr_source_and_schema(query, :post)
      {"posts", EctoShorts.Schemas.Post}

      # It works even if the binding is nested inside a subquery:

      iex> import Ecto.Query
      ...> base_query = from p in EctoShorts.Schemas.Post, as: :post, where: p.published == true
      ...> wrapped_query = from p in subquery(base_query), where: p.id == 1
      ...> EctoShorts.CommonQueries.find_binding_expr_source_and_schema(wrapped_query, :post)
      {"posts", EctoShorts.Schemas.Post}
  """
  @spec find_binding_expr_source_and_schema(
          query_input(),
          binding_alias() | nil
        ) :: source_and_schema() | nil
  def find_binding_expr_source_and_schema(query, binding_alias) do
    case find_binding_expr(query, binding_alias) do
      nil ->
        nil

      {%{assoc: {_binding_position, assoc_key}} = _join_expr, from_expr} ->
        case from_expr.source do
          {_schema_source, schema_module} ->
            schema_module
            |> SchemaHelpers.fetch_association_schema_module!(assoc_key)
            |> normalize_source_and_schema_tuple()

          %{source: _} = _query ->
            from_expr
            |> get_from_expr(:source)
            |> elem(1)
            |> SchemaHelpers.fetch_association_schema_module!(assoc_key)
            |> normalize_source_and_schema_tuple()

          %{query: query} = _subquery ->
            query
            |> get_source_subquery(:query)
            |> get_from_expr(:source)
            |> elem(1)
            |> SchemaHelpers.fetch_association_schema_module!(assoc_key)
            |> normalize_source_and_schema_tuple()
        end

      {%{as: _, on: _} = join_expr, _from_expr} ->
        if has_source_subquery?(join_expr) do
          join_expr
          |> get_source_subquery(:query)
          |> get_from_expr(:source)
          |> normalize_source_and_schema_tuple()
        else
          normalize_source_and_schema_tuple(join_expr.source)
        end

      %{as: _, on: _} = join_expr ->
        if has_source_subquery?(join_expr) do
          join_expr
          |> get_source_subquery(:query)
          |> get_from_expr(:source)
          |> normalize_source_and_schema_tuple()
        else
          normalize_source_and_schema_tuple(join_expr.source)
        end

      expr ->
        if has_source_subquery?(expr) do
          expr
          |> get_source_subquery(:query)
          |> get_from_expr(:source)
          |> normalize_source_and_schema_tuple()
        else
          normalize_source_and_schema_tuple(expr.source)
        end
    end
  end

  defp normalize_source_and_schema_tuple({nil = _schema_source, schema_module}) do
    {schema_module.__schema__(:source), schema_module}
  end

  defp normalize_source_and_schema_tuple({schema_source, schema_module}) do
    {schema_source, schema_module}
  end

  defp normalize_source_and_schema_tuple(schema_module)
       when is_atom(schema_module) and not is_nil(schema_module) do
    {schema_module.__schema__(:source), schema_module}
  end

  @doc """
  Finds the query expression that corresponds to a given binding alias in a
  query or subquery.

  This function retrieves the underlying Ecto query expression (such as a
  `from` or `join`) associated with a specific named binding in your query.
  It works with nested subqueries and joins, traversing through them to
  find the expression that matches the binding alias.

  If a join expression is found, the result returned is a tuple of the join
  expression and the original `from` expression it joins onto.

  If the match is found in the base `from`, only that expression is returned.

  ## Examples

      # From a schema module

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> EctoShorts.CommonQueries.find_binding_expr(query, nil)

      # From a subquery with a named binding

      iex> import Ecto.Query
      ...> base_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> query = from p in subquery(base_query), as: :post, where: p.id == 1
      ...> EctoShorts.CommonQueries.find_binding_expr(query, :post)

      # Subquery join

      iex> import Ecto.Query
      ...> posts_query = from p in EctoShorts.Schemas.Post, where: p.published == true
      ...> comments_query =
      ...>   from c in EctoShorts.Schemas.Comment,
      ...>     join: p in subquery(posts_query),
      ...>     as: :comments,
      ...>     on: c.post_id == p.id
      ...> EctoShorts.CommonQueries.find_binding_expr(comments_query, :comments)

      # Using `assoc/2` for join

      iex> import Ecto.Query
      ...> query =
      ...>   from p in EctoShorts.Schemas.Post,
      ...>     as: :post,
      ...>     join: assoc(p, :comments),
      ...>     as: :comments,
      ...>     on: true
      ...> EctoShorts.CommonQueries.find_binding_expr(query, :comments)
  """
  @spec find_binding_expr(query_input(), binding_alias() | nil) :: binding_expr() | nil
  def find_binding_expr([], _binding_alias) do
    nil
  end

  def find_binding_expr([head | tail] = _joins, binding_alias) do
    with nil <- find_binding_expr(head, binding_alias) do
      find_binding_expr(tail, binding_alias)
    end
  end

  def find_binding_expr(%{from: from_expr, joins: joins}, binding_alias) do
    with nil <- find_binding_expr(from_expr, binding_alias) do
      with %{on: _, as: _} = join_expr <- find_binding_expr(joins, binding_alias) do
        {join_expr, from_expr}
      end
    end
  end

  def find_binding_expr(%{as: as, on: _} = join_expr, binding_alias) do
    if as === binding_alias do
      join_expr
    else
      if has_source_subquery?(join_expr) do
        join_expr
        |> get_source_subquery(:query)
        |> find_binding_expr(binding_alias)
      end
    end
  end

  def find_binding_expr(%{as: as} = from_expr, binding_alias) do
    if as === binding_alias do
      from_expr
    else
      if has_source_subquery?(from_expr) do
        from_expr
        |> get_source_subquery(:query)
        |> find_binding_expr(binding_alias)
      end
    end
  end

  def find_binding_expr(query_source, binding_alias) do
    query_source
    |> to_query()
    |> find_binding_expr(binding_alias)
  end
end
