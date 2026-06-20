defmodule EctoShorts.QueryProvider do
  @moduledoc """
  A contract for supplying named, reusable query fragments to the filter layer.

  Some filter operations — such as joining to a named subquery, applying a
  custom lock clause, or defining a window — need a query expression that cannot
  be expressed as a simple data structure. A query provider lets you give these
  expressions a name and store the logic in one place.

  For example, instead of writing the same subquery inline every time you need
  it, you can name it `:active_posts` in your provider and reference it by name
  in your filter params:

      %{join: %{name: :active_posts}}

  When the filter layer encounters `:name`, it calls your provider with
  `:active_posts` and your provider returns the query.

  ## When to use a query provider

  You only need a query provider when a filter requires logic that cannot be
  described as a plain data structure. Common cases include:

  * A join that uses a subquery you want to reuse across multiple queries.
  * A custom lock string that depends on runtime conditions.
  * A window definition that uses a complex frame clause.

  For most filtering needs, you do not need a query provider at all.

  ## Writing a query provider

  Declare the behaviour and implement `query_expression/4`. Return
  `{:error, :unsupported}` (or similar) for keys your provider does not
  recognize, so the filter layer can log a warning and continue:

      defmodule MyApp.QueryProvider do
        @behaviour EctoShorts.QueryProvider

        @impl true
        def query_expression(selected_binding, expression_key, expression_params, opts) do
          case expression_key do
            :active_users ->
              {:ok, from(u in "users", where: u.active == true)}

            _ ->
              {:error, :unsupported_expression_key}
          end
        end
      end

  Configure it globally in `config/config.exs`:

      config :ecto_shorts, query_provider_module: MyApp.QueryProvider

  Or pass it at the call site:

      EctoShorts.CommonFilters.convert_params_to_filter(
        Post,
        %{join: %{name: :active_users}},
        query_provider: MyApp.QueryProvider
      )

  ## What the provider can return

  `query_expression/4` must return one of:

  * `{:ok, query}` — an `Ecto.Query.t()` to use as a subquery or fragment.
  * `{:ok, function}` — a 1-arity function `(Ecto.Query.t() -> Ecto.Query.t())`
    that is applied to the current query. Use this when you need to modify the
    query directly.
  * `{:ok, keyword}` — a keyword list of options, for example a window
    definition.
  * `{:error, reason}` — the expression could not be resolved. EctoShorts logs
    a warning and skips the expression.
  * `nil` — the expression is silently skipped without a warning.
  """

  @typedoc """
  Identifies which binding in the query a filter applies to.

  * `{:as, name}` — a named binding (for example, `{:as, :author}`).
  * `{:at, position}` — a positional binding, where `1` is the from-binding.
    Positions are 1-based.
  """
  @type selected_binding :: {:as, atom()} | {:at, pos_integer()}

  @typedoc """
  An atom that names the expression to resolve.

  For example, `:active_users` or `:recent_posts`. The meaning of each key is
  defined by your query provider implementation.
  """
  @type expression_key :: atom()

  @typedoc """
  The value associated with the expression key in the filter params.

  The shape is determined by what your query provider expects. It can be any
  term — a map, a keyword list, a scalar value, or `nil`.
  """
  @type expression_params :: term()

  @typedoc """
  Keyword options forwarded from the original call site.

  These are the same options the caller passed to
  `EctoShorts.CommonFilters.convert_params_to_filter/3`. Use them to support
  runtime overrides in your provider.
  """
  @type opts :: keyword()

  @doc """
  Resolves a named query expression from this provider.

  Called by filter modules such as `EctoShorts.CommonFilters.Filters.Join` and
  `EctoShorts.CommonFilters.Filters.Lock` when the filter params include an
  expression key backed by a provider.

  ## Arguments

  * `selected_binding` — which binding in the query this expression applies to.
    See `t:selected_binding/0`.
  * `expression_key` — the atom that identifies which expression to produce.
    Your implementation decides what each key means.
  * `expression_params` — the value from the filter params that was associated
    with `expression_key`. Can be any term your implementation accepts.
  * `opts` — keyword options forwarded from the call site.

  ## Return value

  Must return one of:

  * `{:ok, Ecto.Query.t()}` — a subquery or fragment query.
  * `{:ok, function}` — a 1-arity function `(Ecto.Query.t() -> Ecto.Query.t())`
    that is applied to the current query.
  * `{:ok, keyword()}` — a keyword list of query options (for example, a window
    definition).
  * `{:error, reason}` — signals that the expression could not be resolved. The
    filter layer logs a warning and skips the expression.
  * `nil` — the expression is silently skipped.
  """
  @callback query_expression(
              selected_binding(),
              expression_key(),
              expression_params(),
              opts()
            ) :: {:ok, term()} | {:error, term()} | nil

  @doc false
  @spec query_expression(
          module :: module(),
          selected_binding(),
          expression_key(),
          expression_params(),
          opts()
        ) :: term()
  def query_expression(module, selected_binding, expression_key, expression_params, opts) do
    module.query_expression(selected_binding, expression_key, expression_params, opts)
  end
end
