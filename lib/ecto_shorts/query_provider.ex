defmodule EctoShorts.QueryProvider do
  @moduledoc """
  Public API for resolving dynamic query expressions from a query provider module.

  A query provider is a module that knows how to turn a named expression key and
  its parameters into an Ecto query fragment - such as a subquery, a lock clause,
  or a window definition. This allows callers to supply named, reusable query
  logic without hard-coding it inside the filter layer.

  The active provider is selected by:

    1. The `:query_provider_module` option in the filter params or call-site opts.
    2. `EctoShorts.Config.query_provider_module/0` (configured in application env).

  ## Implementing a query provider

  Define a module with a `query_expression/4` callback:

      defmodule MyApp.QueryProvider do
        def query_expression(selected_binding, expression_key, expression_params, opts) do
          case expression_key do
            :active_users ->
              {:ok, from(u in "users", where: u.active == true)}

            _ ->
              {:error, :unsupported_fragment_key}
          end
        end
      end

  Then configure it globally:

      # config/config.exs
      config :ecto_shorts, query_provider_module: MyApp.QueryProvider

  Or pass it at runtime:

      EctoShorts.CommonFilters.convert_params_to_filter(
        Post,
        %{join: %{name: :active_users}},
        query_provider_module: MyApp.QueryProvider
      )

  ## Return values

  `query_expression/4` must return one of:

    * `{:ok, Ecto.Query.t()}` - a subquery or fragment query.
    * `{:ok, function}` - a unary function `(Ecto.Query.t() -> Ecto.Query.t())` applied to the current query.
    * `{:ok, keyword()}` - a keyword list of query options (e.g. for window definitions).
    * `{:error, reason}` - an error tuple; the filter layer will log a warning and skip the expression.
    * `nil` - treated as "no expression"; the filter layer skips the expression silently.

  ## Implementing this behaviour

  To gain compile-time verification that your provider implements the required
  callback, declare the behaviour on your module:

      defmodule MyApp.QueryProvider do
        @behaviour EctoShorts.QueryProvider

        @impl true
        def query_expression(selected_binding, expression_key, expression_params, opts) do
          case expression_key do
            :active_users -> {:ok, from(u in "users", where: u.active == true)}
            _ -> {:error, :unsupported_fragment_key}
          end
        end
      end
  """

  @type selected_binding :: {:as, atom()} | {:at, pos_integer()}
  @type expression_key :: atom()
  @type expression_params :: term()
  @type opts :: keyword()

  @doc """
  Resolves a named query expression from this provider.

  Called by filter modules such as `EctoShorts.CommonFilters.Join` and
  `EctoShorts.CommonFilters.Lock` when a provider-backed expression key is
  encountered.

    * `selected_binding` - the active binding selector: `{:as, atom()}` or
      `{:at, pos_integer()}`.
    * `expression_key` - the atom key identifying which expression to resolve.
    * `expression_params` - the value associated with the expression key in the
      filter params.
    * `opts` - keyword options forwarded from the call site.

  Must return one of the shapes described in the module doc.
  """
  @callback query_expression(
              selected_binding(),
              expression_key(),
              expression_params(),
              opts()
            ) :: term()

  @doc """
  Dispatches `query_expression/4` to the given provider `module`.

  This is the internal dispatch entry point used by filter modules such as
  `EctoShorts.CommonFilters.Join` and `EctoShorts.CommonFilters.Lock`.
  `module` must implement the `EctoShorts.QueryProvider` behaviour.
  """
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
