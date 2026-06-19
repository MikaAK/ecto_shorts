defmodule EctoShorts.DynamicBuilders do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Entry point for building dynamic filter expressions.

  This module is responsible for turning filter key-value pairs into
  `Ecto.Query.DynamicExpr` values.

  ## Operator routing

  Once the adapter is resolved, each filter operator is normalised and routed to
  one of the Postgres expression sub-modules. The table below lists every
  operator's destination:

  | Operator(s) | Routes to | What it does |
  | --- | --- | --- |
  | `==` `!=` `<` `>` `in` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Comparisons, equality, membership |
  | `like` `ilike` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Pattern matching |
  | `avg` `sum` `max` `min` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Aggregate comparisons |
  | `&&` `@>` (array) | [`ArrayExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Postgres array operators |
  | `before` `after` `since` `until` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Cursor / timestamp filters |
  | `exists` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Existence subqueries |
  | `@>` `<@` `jsonb_exists` | [`MapExpr`](EctoShorts.DynamicBuilders.Postgres.html) | JSONB operators |

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

  All other adapters emit a `Logger.warning` and fall back to
  `EctoShorts.DynamicBuilders.Postgres`, which may generate invalid SQL for that
  database. Provide a custom dynamic adapter to silence the warning and get
  dialect-correct expressions.

  ## Custom adapters

  You may provide your own adapter as long as it implements the
  `EctoShorts.DynamicBuilder` behaviour.

  A custom adapter may be configured in your application environment:

      # config/config.exs
      config :ecto_shorts, dynamic_builder_module: MyApp.DynamicBuilders.Custom

  It may also be passed at call time:

      EctoShorts.DynamicBuilders.build_dynamic(source, binding, term,
        dynamic_builder: MyApp.DynamicBuilders.Custom
      )
  """

  require Logger

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

  @doc since: "3.0.0"
  @doc """
  Builds an `Ecto.Query.DynamicExpr` for one resolved
  `EctoShorts.CommonFilters.Predicate` using the adapter resolved from `opts`.

  The adapter is selected exactly as for `build_dynamic/4`. Returns the dynamic
  expression, or `nil` when the predicate contributes no clause.
  """
  def build_dynamic(%EctoShorts.CommonFilters.Predicate{} = predicate, selected_binding, opts) do
    adapter_for_repo!(opts).build_dynamic(predicate, selected_binding, opts)
  end

  defp adapter_for_repo!(opts) do
    case Keyword.get(opts, :dynamic_builder, EctoShorts.Config.dynamic_builder_module()) do
      nil ->
        repo = opts[:repo] || opts[:replica] || Config.repo!(opts)

        case repo.__adapter__() do
          Ecto.Adapters.Postgres ->
            EctoShorts.DynamicBuilders.Postgres

          adapter ->
            Logger.warning("""
            EctoShorts has no built-in dynamic builder for #{inspect(adapter)}; \
            defaulting to EctoShorts.DynamicBuilders.Postgres, which may generate \
            invalid SQL for this database. Configure a dialect-specific builder via \
            `config :ecto_shorts, dynamic_builder_module: MyApp.DynamicBuilder` or the \
            `:dynamic_builder` call-time option.
            """)

            EctoShorts.DynamicBuilders.Postgres
        end

      module ->
        module
    end
  end
end
