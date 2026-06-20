defmodule EctoShorts.QueryBuilder do
  @moduledoc """
  A contract for applying a single filter entry to an Ecto query.

  When `EctoShorts.CommonFilters.convert_params_to_filter/3` processes a
  params map, it calls one function for each key-value pair in that map. For
  example, `%{published: true, limit: 10}` produces two calls — one for
  `:published` and one for `:limit`. The module that handles each of those
  calls implements this behaviour.

  The default implementation, `EctoShorts.CommonFilters.Builder`, routes each
  key to a dedicated sub-module. For example, `:limit` is handled by
  `EctoShorts.CommonFilters.Filters.Limit`, and field comparisons like
  `:published` are handled by the active `EctoShorts.DynamicBuilder`.

  ## You probably do not need to implement this

  This behaviour is an advanced extension point. Most applications can use
  the default implementation without any configuration.

  You only need a custom implementation if you want to intercept or replace
  how EctoShorts processes filter keys — for example, to add support for a
  completely new kind of filter key, or to change how an existing key works.

  ## Writing a custom implementation

  Declare the behaviour and implement `build_query/6`. You can call the
  default implementation as a fallback for keys you do not override:

      defmodule MyApp.CustomQueryBuilder do
        @behaviour EctoShorts.QueryBuilder

        @impl true
        def build_query(filter, source, query, selected_binding, term, opts) do
          # Handle specific keys and fall through to the default for everything else:
          EctoShorts.CommonFilters.Builder.build_query(
            filter, source, query, selected_binding, term, opts
          )
        end
      end

  Pass it at the call site:

      EctoShorts.CommonFilters.convert_params_to_filter(
        Post,
        %{published: true},
        query_builder: MyApp.CustomQueryBuilder
      )

  Or configure it globally in `config/config.exs`:

      config :ecto_shorts, query_builder_module: MyApp.CustomQueryBuilder
  """

  @doc """
  Applies one filter entry to the query and returns the updated query.

  This callback is called once for each key-value pair in the filter params.
  It must return an `Ecto.Query.t()` — either the query unchanged (if the
  entry should be skipped) or a new query with the entry applied.

  ## Arguments

  * `filter` — the category this entry belongs to. For named filter keys like
    `:limit` or `:order_by`, this is the key itself. For field comparisons
    like `%{title: "Hello"}`, this is `:where` (the current boolean group).
  * `source` — the schema module, `{source, schema}` tuple, or `Ecto.Query.t()`
    that the query is built from.
  * `query` — the `Ecto.Query.t()` accumulated so far. Apply your change to
    this value and return the result.
  * `selected_binding` — which binding in the query this entry targets. See
    `EctoShorts.DynamicBuilder.t:selected_binding/0` for the possible shapes.
  * `term` — the value from the filter params associated with `filter`. For a
    field comparison like `%{title: "Hello"}`, this is `{:title, "Hello"}`.
  * `opts` — keyword options forwarded from the original call site.

  ## Return value

  Must return the updated `Ecto.Query.t()`. Never return `nil` or raise — if
  an entry should be ignored, return `query` unchanged.
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
