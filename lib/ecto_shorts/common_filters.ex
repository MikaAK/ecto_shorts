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
    CommonSchema,
    QueryBuilder,
    QueryBuilders.Common,
    QueryBuilders.Schema
  }

  @type prefix :: binary()
  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source(), schema()}
  @type queryable_input :: schema() | schema_source()
  @type query_input :: query_input()
  @type binding_alias :: atom() | nil
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
  @spec convert_params_to_filter(query_input() | params()) :: query_input()
  @spec convert_params_to_filter(query_input() | params(), params() | opts()) :: query_input()
  def convert_params_to_filter(params, opts \\ [])

  def convert_params_to_filter(query_input, params)
      when is_atom(query_input) or is_struct(query_input) or is_tuple(query_input) do
    convert_params_to_filter(query_input, params, [])
  end

  def convert_params_to_filter(params, opts) when is_list(params) do
    params
    |> Map.new()
    |> convert_params_to_filter(opts)
  end

  def convert_params_to_filter(params, opts) do
    query_input =
      if Map.has_key?(params, :query) do
        params[:query]
      else
        raise KeyError, "key :query not found: #{inspect(params)}"
      end

    schema =
      case params[:schema] do
        nil -> query_input |> CommonSchema.get_schema_source() |> elem(1)
        module -> module
      end

    binding_alias = params[:as]

    from_opts = Map.take(params, [:as, :prefix, :options])

    params = Map.drop(params, [:as, :prefix, :query, :schema, :options])

    query_input
    |> CommonQueryAPI.from(binding_alias, from_opts)
    |> reduce_params(binding_alias, schema, params, opts)
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
  @spec convert_params_to_filter(query_input(), params()) :: query_input()
  @spec convert_params_to_filter(query_input(), params(), opts()) :: query_input()
  def convert_params_to_filter(query_input, params, _opts)
      when params === %{} or params === [] do
    query_input
  end

  def convert_params_to_filter(query_input, params, opts) when is_map(params) do
    convert_params_to_filter(query_input, Map.to_list(params), opts)
  end

  def convert_params_to_filter(query_input, params, opts) do
    {_, schema} = CommonSchema.get_schema_source(query_input)

    {binding_alias, params} = Keyword.pop(params, :as)

    params = ensure_last_is_final_filter(params)

    reduce_params(query_input, binding_alias, schema, params, opts)
  end

  defp reduce_params(query_input, binding_alias, schema, params, opts) do
    Enum.reduce(
      params,
      query_input,
      &apply_query_builder(
        &2,
        binding_alias,
        schema,
        &1,
        opts
      )
    )
  end

  defp apply_query_builder(
         query_input,
         binding_alias,
         schema,
         {key, value},
         opts
       ) do
    if schema_exports_filter?(schema, key) and Keyword.get(opts, :enable_schema_filters, true) do
      if function_exported?(schema, :build_query, 4) do
        schema.build_query(
          query_input,
          binding_alias,
          key,
          value
        )
      else
        EctoShorts.Utils.Logger.warning(
          __MODULE__,
          "callback function build_query/4 not found in schema module #{inspect(schema)} for filter: #{inspect(key)}"
        )

        opts
        |> query_builder_adapter()
        |> QueryBuilder.build_query(
          query_input,
          binding_alias,
          schema,
          key,
          value,
          opts
        )
      end
    else
      opts
      |> query_builder_adapter()
      |> QueryBuilder.build_query(
        query_input,
        binding_alias,
        schema,
        key,
        value,
        opts
      )
    end
  end

  @doc false
  def schema_exports_filter?(schema, key) do
    schema_has_filters?(schema) and key in schema.filters()
  end

  @doc false
  def schema_has_filters?(schema) do
    function_exported?(schema, :filters, 0)
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
          query_input(),
          binding_alias() | nil,
          schema(),
          key(),
          value()
        ) :: query_input()
  @spec build_query(
          query_input(),
          binding_alias() | nil,
          schema(),
          key(),
          value(),
          opts()
        ) :: query_input()
  def build_query(query_input, binding_alias, schema, key, value, opts \\ [])

  def build_query(query_input, binding_alias, schema, key, value, opts)
      when key in @common_filters do
    QueryBuilder.build_query(
      Common,
      query_input,
      binding_alias,
      schema,
      key,
      value,
      opts
    )
  end

  def build_query(query_input, binding_alias, schema, key, value, opts) do
    QueryBuilder.build_query(
      Schema,
      query_input,
      binding_alias,
      schema,
      key,
      value,
      opts
    )
  end
end
