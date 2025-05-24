defmodule EctoShorts.QueryBuilders.Schema do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides schema-aware filtering logic for building dynamic `Ecto.Query`
  expressions.

  This module acts as the core filter engine for structuring queries that are
  dynamically composed from maps or keyword lists. It determines whether each
  filter key corresponds to a known schema field, association, or supported DSL
  extension (e.g., `:join`, `:select`, `:where`) and routes each one to the
  appropriate query builder logic.

  This API is designed to:

    * **Recognize schema fields and apply expressions**, including operator/value
      tuples (e.g., `%{views: %{>=: 10}}`).

    * **Join associations dynamically** and recursively apply filters inside those
      associations.

    * **Integrate with subqueries**, including lists of subqueries or those
      without explicit `:as` bindings.

    * **Handle unsupported keys gracefully**, by logging helpful messages while
      skipping them.

  Internally, this module delegates most query construction to `EctoShorts.CommonQueryAPI`
  and uses `EctoShorts.SchemaHelpers`for schema introspection.

  This module implements the `EctoShorts.QueryBuilder` behaviour.

  ### Supported Filters

  The following filter keys are supported and map to dynamic query operations:

    * `:join` – Joins an association or subquery and applies optional nested filters.

    * `:select` – Selects fields from the root or joined schemas.

    * `:select_merge` – Adds fields to an existing `select`.

    * `:where` – Applies `AND` conditions to fields.

    * `:or_where` – Applies `OR` conditions using the same format as `:where`.

  See `filters/0` for the full list of supported query filters.

  ### Examples

  ```elixir
  # Basic filter on a root schema field
  iex> EctoShorts.QueryBuilders.Schema.build_query(
  ...>   EctoShorts.Schemas.Post,
  ...>   nil,
  ...>   EctoShorts.Schemas.Post,
  ...>   :views,
  ...>   %{>=: 10}
  ...> )

  # Join an association and apply filters inside it
  iex> EctoShorts.QueryBuilders.Schema.build_query(
  ...>   EctoShorts.Schemas.Post,
  ...>   nil,
  ...>   EctoShorts.Schemas.Post,
  ...>   :comments,
  ...>   %{author_id: 5}
  ...> )

  # Apply a join using subquery with a condition
  iex> EctoShorts.QueryBuilders.Schema.build_query(
  ...>   EctoShorts.Schemas.Post,
  ...>   nil,
  ...>   EctoShorts.Schemas.Post,
  ...>   :join,
  ...>   %{subquery: %{query: EctoShorts.Schemas.Comment, where: %{id: 1}}}
  ...> )
  ```
  """
  alias EctoShorts.{
    CommonQuery,
    CommonQueryAPI,
    Utils,
    SchemaHelpers
  }

  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source(), schema()}
  @type queryable_input :: schema() | schema_source()
  @type query_source :: query() | queryable_input()
  @type binding_alias :: atom() | nil
  @type key :: atom()
  @type value :: any()
  @type opts :: keyword()
  @type filter :: :join | :select | :select_merge | :or_where

  @behaviour EctoShorts.QueryBuilder

  @query_api_filters ~w(
    from
    join
    select
    select_merge
    or
    or_where
    where
  )a

  @impl EctoShorts.QueryBuilder
  @doc """
  Returns the list of supported filters that can be used in schema-aware queries.

  These filters delegate to `EctoShorts.CommonQueryAPI` and enable dynamic,
  field-driven construction of queries in a composable and reusable way.

  ### Filter behaviors

    * `:join` – Joins an association or subquery into the query. Supports binding aliasing and prefix options.
    * `:select` – Selects fields from the schema or association. Supports nested field selection using maps.
    * `:select_merge` – Adds additional fields to an existing select expression without overwriting previous fields.
    * `:where` – Adds one or more `AND` conditions to the query using field-value pairs or operator tuples.
    * `:or_where` – Adds one or more `OR` conditions, dynamically constructing boolean expressions across fields.

  ## Examples

      iex> EctoShorts.QueryBuilders.Schema.filters()
      [:from, :join, :select, :select_merge, :or, :or_where, :where]
  """
  @spec filters :: [filter()]
  def filters, do: @query_api_filters

  @impl EctoShorts.QueryBuilder
  @doc """
  Applies a single filter to the query based on a field, association, or supported expression.

  This function determines how to handle the provided filter key:

    * If the key matches a supported filter (e.g., `:select`, `:join`),
      it applies the appropriate query transformation using
      `EctoShorts.CommonQueryAPI`.

    * If the key matches an association in the schema, the query will be
      joined and any nested filters applied to that association.

    * If the key matches a schema field, it applies a standard `where` condition
      with the value or operator/value tuple.

    * If the key is not recognized, it is skipped and a warning is logged.

  ## Examples

      # joins association key
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :comments, %{id: 1}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: c1.id == ^1>

      # joins association key with operator
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :comments, %{id: %{>=: 2}}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: c1.id >= ^2>

      # join on association using query filter and on clause
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :join, %{association: %{comments: %{on: %{id: 2}}}}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, on: c1.id == ^2>

      # join on association using query filter, on clause and operator
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :join, %{association: %{comments: %{on: %{id: %{>=: 2}}}}}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, on: c1.id >= ^2>

      # join on association using query filter, where clause and operator
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :join, %{association: %{comments: %{id: %{>=: 2}}}}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: c1.id >= ^2>

      # join one subquery
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :join, %{subquery: %{query: EctoShorts.Schemas.Comment, where: %{id: 2}}}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in subquery(from c0 in EctoShorts.Schemas.Comment), as: :ecto_shorts_comment, on: true, where: c1.id == ^2>

      # join a list of subqueries
      iex> EctoShorts.QueryBuilders.Schema.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :join, %{subquery: [%{query: EctoShorts.Schemas.Comment, where: %{id: 2}}]}, [])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in subquery(from c0 in EctoShorts.Schemas.Comment), as: :ecto_shorts_comment, on: true, where: c1.id == ^2>
  """
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema(),
          key(),
          value()
        ) :: query() | schema()
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema(),
          key(),
          value(),
          opts()
        ) :: query() | schema()
  def build_query(query, binding_alias, schema, key, value, opts \\ []) do
    cond do
      key in @query_api_filters ->
        build_query_api_filter(query, binding_alias, schema, key, value, opts)

      key in schema.__schema__(:associations) ->
        join_association(
          query,
          binding_alias,
          schema,
          key,
          value,
          opts
        )

      key in schema.__schema__(:query_fields) ->
        build_schema_filter(query, binding_alias, schema, key, value, opts)

      true ->
        message =
          """
          The given key is not a valid field or supported query filter for the schema.

          schema:

          #{inspect(schema)}

          key:

          #{inspect(key)}

          This key has been skipped and the query will be returned as-is.

          To resolve this, you can:

          - Remove the key if it’s unnecessary.

          - Use a supported custom filter, such as:

          #{Enum.map_join(@query_api_filters, "\n", &"* #{&1}")}

          - Use a valid schema field, such as:

          #{Enum.map_join(schema.__schema__(:query_fields), "\n", &"* #{&1}")}

          """

        assoc_warning_message =
          if schema.__schema__(:associations) !== [] do
            """
            - Use a valid association, such as:

            #{Enum.map_join(schema.__schema__(:associations), "\n", &"* #{&1}")}
            """
          else
            ""
          end

        EctoShorts.Utils.Logger.warning(__MODULE__, message <> assoc_warning_message)

        query
    end
  end

  defp reduce_query_params(query, binding_alias, schema, params, opts) do
    Enum.reduce(params, query, fn {key, value}, query ->
      build_query(query, binding_alias, schema, key, value, opts)
    end)
  end

  defp build_schema_filter(query, binding_alias, schema, key, value, opts) do
    Utils.apply_expressions(
      query,
      value,
      fn value, query ->
        apply_schema_filter(query, binding_alias, schema, key, value, opts)
      end,
      opts
    )
  end

  defp apply_schema_filter(query, binding_alias, _schema, key, {operator, value}, opts) do
    CommonQueryAPI.where(query, binding_alias, %{key => %{operator => value}}, opts)
  end

  defp apply_schema_filter(query, binding_alias, schema, key, value, opts) do
    apply_schema_filter(query, binding_alias, schema, key, {:==, value}, opts)
  end

  defp build_query_api_filter(query, _binding_alias, _schema, :from, params, _opts) do
    params
    |> List.wrap()
    |> Enum.reduce(query, fn params, query ->
      {as, params} = Map.pop(params, :as)

      CommonQueryAPI.from(query, as, params)
    end)
  end

  defp build_query_api_filter(query, binding_alias, _schema, :select, value, _opts) do
    CommonQueryAPI.select(query, binding_alias, value)
  end

  defp build_query_api_filter(query, binding_alias, _schema, :select_merge, value, _opts) do
    CommonQueryAPI.select_merge(query, binding_alias, value)
  end

  defp build_query_api_filter(query, binding_alias, _schema, :or, value, opts) do
    CommonQueryAPI.or_where(query, binding_alias, value, opts)
  end

  defp build_query_api_filter(query, binding_alias, _schema, :or_where, value, opts) do
    CommonQueryAPI.or_where(query, binding_alias, value, opts)
  end

  defp build_query_api_filter(query, binding_alias, _schema, :where, value, opts) do
    CommonQueryAPI.where(query, binding_alias, value, opts)
  end

  defp build_query_api_filter(query, binding_alias, schema, :join, params, opts) do
    Enum.reduce(params, query, fn {key, value}, query ->
      build_join_filter(query, binding_alias, schema, key, value, opts)
    end)
  end

  defp build_join_filter(query, binding_alias, schema, :association, params, opts) do
    join_associations(
      query,
      binding_alias,
      schema,
      params,
      opts
    )
  end

  defp build_join_filter(query, binding_alias, _schema, :subquery, params, opts) do
    join_subquery(query, binding_alias, params, opts)
  end

  defp join_associations(
         query,
         binding_alias,
         schema,
         params,
         opts
       ) do
    Enum.reduce(params, query, fn {key, value}, query ->
      join_association(
        query,
        binding_alias,
        schema,
        key,
        value,
        opts
      )
    end)
  end

  defp join_association(
         query,
         binding_alias,
         schema,
         key,
         values,
         opts
       )
       when is_list(values) do
    if Keyword.keyword?(values) do
      join_association(
        query,
        binding_alias,
        schema,
        key,
        Map.new(values),
        opts
      )
    else
      Enum.reduce(values, query, fn params, query ->
        join_association(
          query,
          binding_alias,
          schema,
          key,
          params,
          opts
        )
      end)
    end
  end

  defp join_association(query, binding_alias, schema, key, params, opts) do
    {join_binding_alias, params} = Map.pop(params, :as)

    join_schema =
      case params[:schema] do
        nil -> SchemaHelpers.fetch_schema_association_module!(schema, key)
        module -> module
      end

    join_binding_alias =
      if is_nil(join_binding_alias) do
        key
        |> named_binding()
        |> String.to_atom()
      else
        join_binding_alias
      end

    join_params = Map.take(params, [:as, :qualifier, :query, :schema, :on, :prefix])

    params = Map.drop(params, [:as, :qualifier, :query, :schema, :on, :prefix])

    query
    |> CommonQueryAPI.join(
      binding_alias,
      join_binding_alias,
      :association,
      key,
      join_params,
      opts
    )
    |> reduce_query_params(join_binding_alias, join_schema, params, opts)
  end

  defp join_subquery(query, binding_alias, values, opts) when is_list(values) do
    if Keyword.keyword?(values) do
      join_subquery(query, binding_alias, Map.new(values), opts)
    else
      Enum.reduce(values, query, fn params, query ->
        join_subquery(query, binding_alias, params, opts)
      end)
    end
  end

  defp join_subquery(query, binding_alias, params, opts) do
    {join_binding_alias, params} = Map.pop(params, :as)

    inner_query =
      if Map.has_key?(params, :query) do
        params[:query]
      else
        raise KeyError, "key :query not found, got: #{inspect(params)}"
      end

    join_schema =
      case params[:schema] do
        nil -> inner_query |> CommonQuery.validate_schema_source!(join_binding_alias) |> elem(1)
        module -> module
      end

    join_binding_alias =
      if is_nil(join_binding_alias) do
        join_schema
        |> named_binding_from_module()
        |> String.to_atom()
      else
        join_binding_alias
      end

    join_params = Map.take(params, [:as, :qualifier, :query, :schema, :on, :prefix])

    params = Map.drop(params, [:as, :qualifier, :query, :schema, :on, :prefix])

    query
    |> CommonQueryAPI.join(
      binding_alias,
      join_binding_alias,
      :subquery,
      inner_query,
      join_params,
      opts
    )
    |> reduce_query_params(join_binding_alias, join_schema, params, opts)
  end

  @doc false
  def named_binding_from_module(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> named_binding()
  end

  @doc false
  def named_binding(key) do
    "ecto_shorts_#{key}"
  end
end
