defmodule EctoShorts.Adapter.DynamicBuilder do
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
    2. `EctoShorts.Config.dynamic_builder/0` (configured in application env).
    3. Auto-detected from the configured repo's database adapter (Postgres
      only, out of the box).

  ## Implementing a custom adapter

  Define a module that implements this behaviour:

      defmodule MyApp.CustomAdapter do
        @behaviour EctoShorts.Adapter.DynamicBuilder

        @impl true
        def build_dynamic(source, selected_binding, {key, term}, opts) do
          # Build and return an Ecto.Query.DynamicExpr
        end
      end

  Then configure it:

      # config/config.exs
      config :ecto_shorts, dynamic_builder: MyApp.CustomAdapter

  Or pass it at runtime:

      EctoShorts.Actions.all(Post, %{published: true}, dynamic_builder: MyApp.CustomAdapter)

  ## Callback

  The single required callback is `build_dynamic/4`. It receives:

    * `source` - the queryable source (schema module or `Ecto.Query.t()`).

    * `selected_binding` - the binding selector: `{:as, atom()}` for named
      bindings or `{:at, pos_integer()}` for positional bindings.

    * `{key, term}` - the filter entry to translate. `key` is an atom field name
      or operator, `term` is the filter value.

    * `opts` - keyword options forwarded from the call site.

  It must return an `Ecto.Query.DynamicExpr` (the result of `Ecto.Query.dynamic/2`).
  """

  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}

  @type source :: term()
  @type selected_binding :: {:as, atom()} | {:at, pos_integer()}
  @type input :: term()
  @type opts :: keyword()

  @doc """
  Builds a dynamic expression for the given filter entry and binding.

  Receives the source queryable, binding selector, a `{key, term}` filter pair,
  and options. Must return an `Ecto.Query.DynamicExpr`.
  """
  @callback build_dynamic(source, selected_binding, input, opts) :: dynamic_expr()
end
