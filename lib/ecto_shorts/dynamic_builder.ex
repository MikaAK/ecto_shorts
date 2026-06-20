defmodule EctoShorts.DynamicBuilder do
  @moduledoc """
  A contract for building database-specific filter expressions.

  When you call `EctoShorts.CommonFilters.convert_params_to_filter/3`, each
  filter condition in your params — for example `%{published: true}` or
  `%{views: %{>: 100}}` — eventually needs to be turned into a real Ecto
  `WHERE` clause. The job of turning a single condition into that clause belongs
  to a module that implements this behaviour.

  In Ecto, a `WHERE` clause is represented as a `DynamicExpr` — a small
  data structure created by the `Ecto.Query.dynamic/2` macro. This behaviour
  defines one callback, `build_dynamic/3`, which receives a description of a
  single filter condition and must return a `DynamicExpr`.

  ## You probably do not need to implement this

  EctoShorts ships with a built-in implementation for PostgreSQL:
  `EctoShorts.DynamicBuilders.Postgres`. When your application connects to
  a PostgreSQL database, EctoShorts detects this automatically and uses that
  implementation.

  You only need to write a custom implementation if you are using a database
  that EctoShorts does not support yet, or if you need to change how a
  specific filter operator is compiled.

  ## How EctoShorts picks an implementation

  EctoShorts resolves the implementation in this order:

    1. The `:dynamic_builder` option passed directly to the function call.
    2. The `:dynamic_builder_module` key in your application config.
    3. Auto-detected from the database your repo is connected to (PostgreSQL
       is the only database supported out of the box).

  ## Writing a custom implementation

  Declare the behaviour in your module and implement the required callback:

      defmodule MyApp.CustomDynamicBuilder do
        @behaviour EctoShorts.DynamicBuilder

        @impl true
        def build_dynamic(predicate, selected_binding, opts) do
          # Return an Ecto.Query.DynamicExpr or nil
        end
      end

  Then tell EctoShorts to use it. Either configure it globally in
  `config/config.exs`:

      config :ecto_shorts, dynamic_builder_module: MyApp.CustomDynamicBuilder

  Or pass it at the call site:

      EctoShorts.Actions.all(Post, %{published: true},
        dynamic_builder: MyApp.CustomDynamicBuilder
      )

  > #### Upgrading from v2 {: .info}
  >
  > In v3.0.0 the callback receives an `EctoShorts.CommonFilters.Predicate`
  > struct instead of a raw `{key, value}` pair. Field resolution, type
  > casting, and operator normalization now happen before your callback is
  > called. Update your `build_dynamic/3` implementation to accept the new
  > struct.
  """

  @typedoc """
  An Ecto dynamic expression produced by the `dynamic/2` macro.

  This is what `build_dynamic/3` must return. Ecto combines these expressions
  into `WHERE` clauses. When the predicate contributes no clause (for example,
  because the value is ignored), return `nil` instead.
  """
  @type dynamic_expr :: term()

  @typedoc """
  A fully resolved filter predicate passed to `build_dynamic/3`.

  See `EctoShorts.CommonFilters.Predicate` for a description of each field.
  """
  @type predicate :: EctoShorts.CommonFilters.Predicate.t()

  @typedoc """
  Identifies which binding in the query a filter applies to.

  * `{:as, name}` — a named binding. For example, `{:as, :author}` targets the
    binding added by `join: ..., as: :author`.
  * `{:at, position}` — a positional binding, where `1` is the from-binding
    (the primary source). Positions are 1-based.
  """
  @type selected_binding :: {:as, atom()} | {:at, pos_integer()}

  @typedoc """
  Keyword options forwarded from the original call site.

  These are the same options the caller passed to
  `EctoShorts.CommonFilters.convert_params_to_filter/3`. Use them to support
  runtime overrides in your adapter.
  """
  @type opts :: keyword()

  @doc """
  Converts one resolved filter predicate into an Ecto dynamic expression.

  This is the only callback you must implement. It receives a fully resolved
  `EctoShorts.CommonFilters.Predicate` struct — the field name, expression
  family, whether the condition is negated, and the operator-value pair — and
  must return either a dynamic expression (from `Ecto.Query.dynamic/2`)
  or `nil`.

  ## Arguments

  * `predicate` — the resolved predicate. See `t:predicate/0` and
    `EctoShorts.CommonFilters.Predicate` for field descriptions.
  * `selected_binding` — which binding in the query this filter targets. See
    `t:selected_binding/0`.
  * `opts` — keyword options forwarded from the call site.

  ## Return value

  Return a dynamic expression when the predicate produces a WHERE
  clause. Return `nil` when the predicate should contribute nothing.
  """
  @callback build_dynamic(predicate, selected_binding, opts) :: dynamic_expr() | nil
end
