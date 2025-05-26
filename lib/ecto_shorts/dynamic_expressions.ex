defmodule EctoShorts.DynamicExpressions do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Dynamic expressions in `EctoShorts` provide a flexible adapter aware
  way to build Ecto query dynamic expressions. These dynamic expressions
  are typically used to construct `where` and `or_where` filters without
  requiring users to manually write `Ecto.Query.dynamic/2` code.

  ## Adapter Support

  The dynamic expressions API is designed to be adapter-aware, with each
  adapter implementing the `EctoShorts.DynamicExpression` behaviour. This
  allows each adapter to account for its own syntax, capabilities, and
  idioms.

  ### Currently Supported Adapters

    - `EctoShorts.DynamicExpressions.Postgres` - Supports building dynamic
      expressions when using `Ecto.Adapters.Postgres`.

  Additional adapter modules can be added in the future by implementing the
  `EctoShorts.DynamicExpression` behaviour.

  See `EctoShorts.DynamicExpression` for information on creating your own
  adapter.
  """

  alias EctoShorts.Config
  alias EctoShorts.DynamicExpression
  alias EctoShorts.Utils

  @type schema :: Ecto.Queryable.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type maybe_dynamic_expr :: dynamic_expr() | nil
  @type binding_alias :: atom() | nil
  @type condition :: :and | :or
  @type key :: atom()
  @type value :: any()
  @type opts :: keyword()

  @default_adapter EctoShorts.DynamicExpressions.Postgres

  @default_adapters [
    {Ecto.Adapters.Postgres, adapter: EctoShorts.DynamicExpressions.Postgres}
  ]

  @doc false
  def default_adapters, do: @default_adapters

  def convert_params_to_dynamic(binding_alias, source, params, opts) do
    {as, params} = Map.pop(params, :as, binding_alias)

    {dyn, params} = Map.pop(params, :dynamic)

    params
    |> normalize_conditions()
    |> Enum.reduce(dyn, fn
      {condition, params}, dyn ->
        Utils.apply_expressions(
          dyn,
          params,
          fn {key, value}, dyn ->
            build_dynamic(
              dyn,
              as,
              condition,
              source,
              key,
              value,
              opts
            )
          end,
          opts
        )
    end)
  end

  defp normalize_conditions(params) do
    {cons, acc} =
      Enum.reduce(params, {[], []}, fn
        {:and, params}, {cons, acc} -> {[{:and, params} | cons], acc}
        {:or, params}, {cons, acc} -> {[{:or, params} | cons], acc}
        {key, value}, {cons, acc} -> {cons, [{key, value} | acc]}
      end)

    cons
    |> Kernel.++(and: acc)
    |> Enum.sort()
  end

  @doc """
  Creates a dynamic expression or applies a dynamic expression
  to an existing dynamic expression.

  ## Options

    * `:dynamic_expression_adapter` - Specifies the dynamic builder adapter to use.

    * `:dynamic_expression_adapters` - Specifies the dynamic builder adapter
      to associate with each ecto repo adapter in your application. This can
      be a enumerable of key-value pairs where the `key` is the repo adapter
      module and the value is a keyword list of options that must contain the
      `:adapter` key, for example:

      - `%{Ecto.Adapters.Postgres => [adapter: EctoShorts.DynamicExpressions.Postgres]}`
      - `[{Ecto.Adapters.Postgres, adapter: EctoShorts.DynamicExpressions.Postgres}]`)

  ## Examples

        iex> EctoShorts.DynamicExpressions.build_dynamic(EctoShorts.Schemas.Post, nil, :and, nil, :tags, {:==, "blog"}, [])
  """
  def build_dynamic(
        dyn,
        binding_alias,
        condition,
        source,
        key,
        value,
        opts \\ []
      ) do
    opts
    |> adapter!()
    |> DynamicExpression.build_dynamic(
      dyn,
      binding_alias,
      condition,
      source,
      key,
      value
    )
  end

  defp adapter!(opts) do
    if Keyword.has_key?(opts, :dynamic_expression_adapter) do
      opts[:dynamic_expression_adapter]
    else
      case adapter_for_repo(Config.repo!(opts).__adapter__(), opts) do
        nil -> @default_adapter
        {_, adapter_config} -> Keyword.fetch!(adapter_config, :adapter)
      end
    end
  end

  defp adapter_for_repo(repo_adapter, opts) do
    opts
    |> adapters()
    |> Enum.find(fn {key, _} -> key === repo_adapter end)
  end

  defp adapters(opts) do
    opts[:dynamic_expression_adapters] ||
      Config.dynamic_expression_adapters() ||
      @default_adapters
  end
end
