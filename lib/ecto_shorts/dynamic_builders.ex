defmodule EctoShorts.DynamicBuilders do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Entry point for building dynamic filter expressions.

  This module is responsible for turning filter key-value pairs into
  `Ecto.Query.DynamicExpr` values.

  ## Operator routing

  Once the adapter is resolved, each filter operator is normalised and routed to
  one of the Postgres expression sub-modules. Drag the adapter hubs apart to see
  which operators each one owns, and how `Normalizer` rewrites aliases:

  ```cytoscape
  {
    "title": "Operator routing",
    "height": 520,
    "layout": {
      "name": "concentric",
      "minNodeSpacing": 40,
      "concentric": "function(n){ return n.data('tier'); }",
      "levelWidth": "function(){ return 1; }"
    },
    "elements": [
      {"data": {"id": "norm",   "label": "Normalizer",  "tier": 3, "kind": "module"}},
      {"data": {"id": "scalar", "label": "ScalarExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "array",  "label": "ArrayExpr",   "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "common", "label": "CommonExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "map",    "label": "MapExpr",     "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},

      {"data": {"id": "eq",   "label": "==, !=, <, >, in", "tier": 1}},
      {"data": {"id": "like", "label": "like, ilike",      "tier": 1}},
      {"data": {"id": "agg",  "label": "avg, sum, max, min", "tier": 1}},
      {"data": {"id": "arr",  "label": "&&, @> (array)",   "tier": 1}},
      {"data": {"id": "cur",  "label": "before, after, since, until", "tier": 1}},
      {"data": {"id": "ex",   "label": "exists",           "tier": 1}},
      {"data": {"id": "json", "label": "@>, <@, jsonb_exists", "tier": 1}},

      {"data": {"source": "eq",   "target": "scalar"}},
      {"data": {"source": "like", "target": "scalar"}},
      {"data": {"source": "agg",  "target": "scalar"}},
      {"data": {"source": "arr",  "target": "array"}},
      {"data": {"source": "cur",  "target": "common"}},
      {"data": {"source": "ex",   "target": "common"}},
      {"data": {"source": "json", "target": "map"}},

      {"data": {"source": "norm", "target": "eq",   "label": "eq->=="}},
      {"data": {"source": "norm", "target": "like", "label": "downcase->lower"}}
    ]
  }
  ```

  `EctoShorts.DynamicBuilders` delegates the work to a dynamic adapter. The adapter
  may be given explicitly, configured globally, or inferred from the repo
  adapter. This allows callers to build dynamic expressions without depending
  on database-specific modules.

  ## Adapter resolution

  The dynamic adapter is resolved in the following order:

    1. The `:dynamic_builder` option passed at call time
    2. `EctoShorts.Config.dynamic_builder/0`
    3. The repo database adapter

  At the moment, the following repo adapters are supported for inference:

    * `Ecto.Adapters.Postgres` - resolves to `EctoShorts.DynamicBuilders.Postgres`

  All other adapters raise at runtime unless a custom dynamic adapter is
  provided.

  ## Custom adapters

  You may provide your own adapter as long as it implements the
  `EctoShorts.DynamicBuilder` behaviour.

  A custom adapter may be configured in your application environment:

      # config/config.exs
      config :ecto_shorts, dynamic_builder: MyApp.DynamicBuilders.Custom

  It may also be passed at call time:

      EctoShorts.DynamicBuilders.build_dynamic(source, binding, term,
        dynamic_builder: MyApp.DynamicBuilders.Custom
      )
  """

  alias EctoShorts.Config

  @doc since: "3.0.0"
  @doc """
  Builds an `Ecto.Query.DynamicExpr` for `term` using the adapter resolved
  from `opts` (or from the configured repo).

  ## Arguments

    * `source` - the queryable source: a schema module, `{source, schema}`
      tuple, or an existing `Ecto.Query`.
    * `selected_binding` - the binding selector: `{:as, atom()}` for a
      named binding or `{:at, pos_integer()}` for a positional binding.
      Use `{:as, nil}` to target the default (first) binding.
    * `term` - the filter term to translate. Typically a `{key, value}`
      pair where `key` is a field atom and `value` is the filter
      expression (scalar, keyword list of operators, range, etc.).
    * `opts` - keyword options forwarded to the adapter.

  ## Options

    * `:dynamic_builder` - a module implementing
      `EctoShorts.DynamicBuilder`. Overrides all other resolution.
    * `:repo` - the repo to use for adapter auto-detection.
    * `:replica` - fallback repo when `:repo` is not given.

  ## Returns

  An `Ecto.Query.DynamicExpr` suitable for use with `Ecto.Query.where/3`,
  `Ecto.Query.or_where/3`, `Ecto.Query.having/3`, etc.

  ## Examples

      iex> EctoShorts.DynamicBuilders.build_dynamic(Post, {:as, nil}, {:views, 5}, repo: MyApp.Repo)
      #Ecto.Query.DynamicExpr<...>

      iex> EctoShorts.DynamicBuilders.build_dynamic(
      ...>   Post,
      ...>   {:as, nil},
      ...>   {:views, [>: 1, <: 10]},
      ...>   repo: MyApp.Repo
      ...> )
      #Ecto.Query.DynamicExpr<...>
  """
  def build_dynamic(source, selected_binding, term, opts) do
    adapter_for_repo!(opts).build_dynamic(source, selected_binding, term, opts)
  end

  defp adapter_for_repo!(opts) do
    case Keyword.get(opts, :dynamic_builder, EctoShorts.Config.dynamic_builder_module()) do
      nil ->
        repo = opts[:repo] || opts[:replica] || Config.repo!(opts)

        case repo.__adapter__() do
          Ecto.Adapters.Postgres ->
            EctoShorts.DynamicBuilders.Postgres

          Ecto.Adapters.MyXQL ->
            raise "Adapter not yet implemented: Ecto.Adapters.MyXQL"

          Ecto.Adapters.SQL ->
            raise "Adapter not yet implemented: Ecto.Adapters.SQL"

          Ecto.Adapters.Tds ->
            raise "Adapter not yet implemented: Ecto.Adapters.SQL"

          adapter ->
            raise "The adapter #{inspect(adapter)} is not supported. You must specify the option :dynamic_builder..."
        end

      module ->
        module
    end
  end
end
