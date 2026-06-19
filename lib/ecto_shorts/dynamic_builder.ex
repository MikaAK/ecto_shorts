defmodule EctoShorts.DynamicBuilder do
  @moduledoc """
  Behaviour for dynamic expression adapters.

  A dynamic expression adapter translates a filter key-value pair into an
  `Ecto.Query.DynamicExpr` for a specific database dialect. The adapter is
  responsible for all dialect-specific expression building - operator dispatch,
  value normalization, and Ecto `dynamic/2` macro calls.

  The following adapters are available out of the box:

  * `EctoShorts.DynamicBuilders.Postgres` - Postgres-specific expression
    building including scalar comparisons, array operations, quantified
    subqueries, and datetime arithmetic.

  ## How adapters are selected

  The active adapter is resolved in order:

    1. The `:dynamic_builder` option passed at call time.
    2. `EctoShorts.Config.dynamic_builder_module/0` (configured in application env).
    3. Auto-detected from the configured repo's database adapter (Postgres
      only, out of the box).

  ## Implementing a custom adapter

  Define a module that implements this behaviour:

      defmodule MyApp.CustomAdapter do
        @behaviour EctoShorts.DynamicBuilder

        @impl true
        def build_dynamic(predicate, selected_binding, opts) do
          # Build and return an Ecto.Query.DynamicExpr (or nil)
        end
      end

  Then configure it:

      # config/config.exs
      config :ecto_shorts, dynamic_builder_module: MyApp.CustomAdapter

  Or pass it at runtime:

      EctoShorts.Actions.all(Post, %{published: true}, dynamic_builder: MyApp.CustomAdapter)

  ## Callback

  > #### v3.0.0 migration note {: .info}
  >
  > As of v3.0.0 the callback consumes a resolved
  > `EctoShorts.CommonFilters.Predicate` struct rather than a raw `{key, term}`
  > filter pair. All field resolution, type casting, operator canonicalization
  > and negation lifting now happen upstream in
  > `EctoShorts.CommonFilters.PredicateBuilder`; the adapter only dispatches the
  > already-tidied predicate to the dialect's expression builders. Custom-dialect
  > implementers must update their `build_dynamic/3` accordingly. Only the
  > Postgres adapter ships in-tree.

  The single required callback is `build_dynamic/3`. It receives:

    * `predicate` - a resolved `EctoShorts.CommonFilters.Predicate` struct with a
      `:field` (already a checked atom), a `:routing` family
      (`:scalar | :array | :map | :common`), a `:negated` boolean, and a tidied
      `:expr` operator-expression.

    * `selected_binding` - the binding selector: `{:as, atom()}` for named
      bindings or `{:at, pos_integer()}` for positional bindings.

    * `opts` - keyword options forwarded from the call site.

  It must return an `Ecto.Query.DynamicExpr` (the result of `Ecto.Query.dynamic/2`)
  or `nil` when the predicate contributes no clause.
  """

  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}

  @type predicate :: EctoShorts.CommonFilters.Predicate.t()
  @type selected_binding :: {:as, atom()} | {:at, pos_integer()}
  @type opts :: keyword()

  @doc """
  Builds a dynamic expression for one resolved predicate and binding.

  Receives a `EctoShorts.CommonFilters.Predicate` struct, a binding selector, and
  options. Must return an `Ecto.Query.DynamicExpr` or `nil`.
  """
  @callback build_dynamic(predicate, selected_binding, opts) :: dynamic_expr() | nil
end
