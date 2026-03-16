defmodule EctoShorts.Adapter.QueryBuilder do
  @moduledoc """
  Behaviour defining the query-builder API.

  A query builder is a module that knows how to translate a filter key into a
  modification of an `Ecto.Query.t()`.

  `EctoShorts.CommonFilters` is the default implementation which routes each
  filter key to the appropriate sub-module (e.g. `Where`, `Join`, `OrderBy`)
  and applies the result to the query.

  You can supply a custom query builder to intercept or override filter
  processing at the top level:

      defmodule MyApp.CustomQueryBuilder do
        @behaviour EctoShorts.Adapter.QueryBuilder

        @impl true
        def build_query(filter, source, query, selected_binding, term, opts) do
          # Custom logic; fall through to default if desired:
          EctoShorts.CommonFilters.build_query(filter, source, query, selected_binding, term, opts)
        end
      end

  Then pass it at runtime:

      EctoShorts.CommonFilters.convert_params_to_filter(
        Post,
        %{published: true},
        query_builder: MyApp.CustomQueryBuilder
      )

  Or configure a global default:

      # config/config.exs
      config :ecto_shorts, query_builder: MyApp.CustomQueryBuilder
  """

  @doc """
  Applies a single filter entry to the given query.

  Receives:

    * `filter` - the filter group atom (e.g. `:where`, `:order_by`, `:join`).
    * `source` - the queryable source (schema module or `Ecto.Query.t()`).
    * `query` - the current `Ecto.Query.t()` being built.
    * `selected_binding` - the active binding selector: `{:as, atom()}` for
      named bindings or `{:at, pos_integer()}` for positional bindings.
    * `term` - the filter value for this entry.
    * `opts` - keyword options forwarded from the call site.

  Must return the updated `Ecto.Query.t()`.
  """
  @callback build_query(
              filter :: atom(),
              source :: term(),
              query :: Ecto.Query.t(),
              selected_binding :: {:as, atom()} | {:at, pos_integer()},
              term :: term(),
              opts :: keyword()
            ) :: Ecto.Query.t()
end
