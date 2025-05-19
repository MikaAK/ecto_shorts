defmodule EctoShorts.CommonFilters do
  @moduledoc """
  Data-driven query composition for Ecto.

  `EctoShorts.CommonFilters` provides a declarative interface for building
  Ecto queries using maps or keyword lists. It enables dynamic query
  generation without requiring direct use of Ecto’s query DSL.

  This reduces boilerplate and makes it easier to build data-driven APIs
  where filters are derived from user input or external sources.

  For example, rather than writing:

      from p in Post,
        where: p.id == 1,
        join: c in assoc(p, :comments),
        where: c.body == "example"

  You can represent the same logic with:

      %{id: 1, comments: %{body: "example"}}

  and pass it to `convert_params_to_filter/2`.

  ## Example Usage

  Find a post by ID:

      EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, %{id: 1})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.id == ^1>

  Join on an association and filter nested fields:

      EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, %{
         id: 1,
         comments: %{
           id: [1, 2],
           body: %{
             ilike: "example"
           }
         }
      })
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: p0.id == ^1, where: c1.id in ^[1, 2], where: ilike(c1.body, ^"%example%")>

  ## Filter API

  The filtering API is split between the following modules:

    * `EctoShorts.QueryBuilders.Common` — Handles common filters like
      pagination, ordering, and range based conditions.

    * `EctoShorts.QueryBuilders.Schema` — Handles schema specific
      filters and joins on associations or subqueries.

  ## Query Builder adapter

  This module is an implementation of the `EctoShorts.QueryBuilder` adapter.
  See the module documentation for information on building your own.
  """

  alias EctoShorts.{
    CommonQueryAPI,
    CommonSchemas,
    QueryBuilder,
    QueryBuilders.Common,
    QueryBuilders.Schema
  }

  @type prefix :: binary()
  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type query_source :: query_source()
  @type binding_alias :: atom()
  @type key :: atom()
  @type value :: any()
  @type params :: keyword() | map()
  @type opts :: keyword()

  @behaviour EctoShorts.QueryBuilder

  @default_query_builder_adapter EctoShorts.CommonFilters

  @common_filters Common.filters()

  @schema_filters Schema.filters()

  @filters Enum.sort(@common_filters ++ @schema_filters)

  @doc group: "Filter API"
  @doc since: "2.5.0"
  @doc """
  Converts a set of parameters into an `Ecto.Query`.

  ## Supported Parameters

  This function supports multiple forms of input for flexibility:

  1. **Simple Schema + Filter Map**

    You can pass a schema module as the first argument and a map or keyword
    list as the second:

        EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, %{id: 1})

  2. **Query Map**

    You can pass a single map with a `:query` key containing the schema or
    base query. This form also supports additional metadata:

        EctoShorts.CommonFilters.convert_params_to_filter(%{
          query: EctoShorts.Schemas.Post,
          as: :post,
          where: %{id: 1}
        })

  3. **Keyword Lists**

    You can use keyword lists to express filters, especially for flat queries:

        EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, [title: "Hello", limit: 10])

  4. **Empty Input**

    If filters are an empty map or list, the original query is returned unchanged.

  ## Metadata Keys (when using the query map form)

  When you pass a map as the only argument (the query map form), you may include:

    * `:query` – The base query or schema module (required)
    * `:queryable` – An optional override for determining field types
    * `:as` – The named binding alias to use in the query
    * `:prefix` – Database prefix to use
    * `:options` – Additional options passed to filter builders

  ## Examples

      # Basic filter using a schema:

      iex> EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, %{id: 1})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.id == ^1>

      # Join and nested filter using query map form:

      iex> EctoShorts.CommonFilters.convert_params_to_filter(%{
      ...>   query: EctoShorts.Schemas.Post,
      ...>   as: :post,
      ...>   comments: %{body: %{ilike: "awesome"}}
      ...> })
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: ilike(c1.body, ^"%awesome%")>

      # Filter using keyword list:

      iex> EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, [title: "Hello", limit: 5])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.title == ^"Hello", limit: ^5>

      # Ignore empty filter set:

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post
      ...> EctoShorts.CommonFilters.convert_params_to_filter(query, %{})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post>
  """
  @spec convert_params_to_filter(query_source() | params()) :: query_source()
  @spec convert_params_to_filter(query_source() | params(), params() | opts()) :: query_source()
  def convert_params_to_filter(params, opts \\ [])

  def convert_params_to_filter(query_source, params)
      when is_atom(query_source) or is_struct(query_source) or is_tuple(query_source) do
    convert_params_to_filter(query_source, params, [])
  end

  def convert_params_to_filter(params, opts) when is_list(params) do
    params
    |> Map.new()
    |> convert_params_to_filter(opts)
  end

  def convert_params_to_filter(params, opts) do
    {query_source, params} = Map.pop(params, :query)

    if is_nil(query_source) do
      raise KeyError, "key :query not found, got: #{inspect(params)}"
    end

    {schema_module, params} = Map.pop(params, :queryable)

    schema_module =
      with nil <- schema_module do
        CommonSchemas.get_source_and_schema(query_source, :schema)
      end

    binding_alias = params[:as]
    base_params = Map.take(params, [:as, :prefix, :options])
    params = Map.drop(params, [:as, :prefix, :options])

    query_source
    |> CommonQueryAPI.from(binding_alias, base_params)
    |> reduce_params_to_filters(binding_alias, schema_module, params, opts)
  end

  @doc group: "Filter API"
  @doc """
  Converts a map or keyword list of parameters into an Ecto query.

  ## Examples

      iex> EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schemas.Post, %{id: 1})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.id == ^1>

      iex> EctoShorts.CommonFilters.convert_params_to_filter(%{query: EctoShorts.Schemas.Post, as: :post, where: %{id: 1}})
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post, where: p0.id == ^1>
  """
  @spec convert_params_to_filter(query_source(), params()) :: query_source()
  @spec convert_params_to_filter(query_source(), params(), opts()) :: query_source()
  def convert_params_to_filter(query_source, params, _opts)
      when params === %{} or params === [] do
    query_source
  end

  def convert_params_to_filter(query_source, params, opts) when is_map(params) do
    convert_params_to_filter(query_source, Map.to_list(params), opts)
  end

  def convert_params_to_filter(query_source, params, opts) do
    schema_module = CommonSchemas.get_source_and_schema(query_source, :schema)

    {binding_alias, params} = Keyword.pop(params, :as)

    params = ensure_last_is_final_filter(params)

    reduce_params_to_filters(query_source, binding_alias, schema_module, params, opts)
  end

  defp reduce_params_to_filters(query_source, binding_alias, schema_module, params, opts) do
    Enum.reduce(
      params,
      query_source,
      &build_with_schema_or_adapter(
        &2,
        binding_alias,
        schema_module,
        &1,
        opts
      )
    )
  end

  defp build_with_schema_or_adapter(
         query_source,
         binding_alias,
         schema_module,
         {key, value},
         opts
       ) do
    if schema_exports_filter?(schema_module, key) do
      if function_exported?(schema_module, :build_query, 4) do
        schema_module.build_query(
          query_source,
          binding_alias,
          key,
          value
        )
      else
        EctoShorts.Utils.Logger.warning(
          __MODULE__,
          "callback function build_query/4 not found in schema module #{inspect(schema_module)} for filter: #{inspect(key)}"
        )

        build_query_with_adapter(
          query_source,
          binding_alias,
          schema_module,
          key,
          value,
          opts
        )
      end
    else
      build_query_with_adapter(
        query_source,
        binding_alias,
        schema_module,
        key,
        value,
        opts
      )
    end
  end

  @doc false
  def build_query_with_adapter(
        query_source,
        binding_alias,
        schema_module,
        key,
        value,
        opts
      ) do
    opts
    |> query_builder_adapter()
    |> QueryBuilder.build_query(
      query_source,
      binding_alias,
      schema_module,
      key,
      value,
      opts
    )
  end

  @doc false
  def schema_exports_filter?(schema_module, key) do
    schema_has_filters?(schema_module) and key in schema_module.filters()
  end

  @doc false
  def schema_has_filters?(schema_module) do
    function_exported?(schema_module, :filters, 0)
  end

  defp ensure_last_is_final_filter(params) do
    if Keyword.has_key?(params, :last) do
      params
      |> Keyword.delete(:last)
      |> Kernel.++(last: params[:last])
    else
      params
    end
  end

  defp query_builder_adapter(opts) do
    opts[:query_builder_adapter] ||
      EctoShorts.Config.query_builder_adapter() ||
      @default_query_builder_adapter
  end

  @impl EctoShorts.QueryBuilder
  @doc group: "Query Builder API"
  @doc since: "2.5.0"
  @doc """
  Returns the list of support filters.

  ## Examples

      iex> EctoShorts.CommonFilters.filters()
      [
        :after,
        :before,
        :end_date,
        :first,
        :from,
        :ids,
        :join,
        :last,
        :limit,
        :offset,
        :or,
        :or_where,
        :order_by,
        :preload,
        :search,
        :select,
        :select_merge,
        :since,
        :start_date,
        :until,
        :where
      ]
  """
  def filters, do: @filters

  @impl EctoShorts.QueryBuilder
  @doc group: "Query Builder API"
  @doc since: "2.5.0"
  @doc """
  Builds a query based on a single filter key and value.

  The schema module given as an argument must be the schema module
  for the query being targeted by the binding_alias argument. If
  the binding_alias is `nil` then the binding is the root query
  and the schema module must be for the root query. If the
  binding_alias given is an association then the schema module
  must be for that association schema module.

  ## Examples

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonFilters.build_query(query, :post, EctoShorts.Schemas.Post, :limit, 10)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post, limit: ^10>

      iex> import Ecto.Query
      ...> query = from p in EctoShorts.Schemas.Post, as: :post
      ...> EctoShorts.CommonFilters.build_query(query, :post, EctoShorts.Schemas.Post, :title, "Hello")
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, as: :post, where: p0.title == ^"Hello">
  """
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema_module(),
          key(),
          value()
        ) :: query_source()
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema_module(),
          key(),
          value(),
          opts()
        ) :: query_source()
  def build_query(query_source, binding_alias, schema_module, key, value, opts \\ [])

  def build_query(query_source, binding_alias, schema_module, key, value, opts)
      when key in @common_filters do
    QueryBuilder.build_query(
      Common,
      query_source,
      binding_alias,
      schema_module,
      key,
      value,
      opts
    )
  end

  def build_query(query_source, binding_alias, schema_module, key, value, opts) do
    QueryBuilder.build_query(
      Schema,
      query_source,
      binding_alias,
      schema_module,
      key,
      value,
      opts
    )
  end
end
