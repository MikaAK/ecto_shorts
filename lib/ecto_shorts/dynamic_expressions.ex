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

  @type schema_module :: Ecto.Queryable.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type maybe_dynamic_expr :: dynamic_expr() | nil
  @type binding_alias :: atom()

  @type condition :: :and | :or

  @type key :: atom()
  @type value :: any()
  @type opts :: keyword()

  @default_adapter EctoShorts.DynamicExpressions.Postgres

  @default_adapters %{
    Ecto.Adapters.Postgres => [adapter: EctoShorts.DynamicExpressions.Postgres]
  }

  @doc false
  @spec default_adapters :: %{module() => keyword()}
  def default_adapters, do: @default_adapters

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

        iex> EctoShorts.DynamicExpressions.create_dynamic(EctoShorts.Schema.Post, nil, nil, :and, :tags, {:==, "blog"}, [])
  """
  @spec create_dynamic(
          schema_module(),
          maybe_dynamic_expr(),
          binding_alias() | nil,
          condition(),
          key(),
          value()
        ) :: dynamic_expr()
  @spec create_dynamic(
          schema_module(),
          maybe_dynamic_expr(),
          binding_alias() | nil,
          condition(),
          key(),
          value(),
          opts()
        ) :: dynamic_expr()
  def create_dynamic(
        schema_module,
        dyn,
        binding_alias,
        condition,
        key,
        value,
        opts \\ []
      ) do
    opts
    |> adapter!()
    |> DynamicExpression.create_dynamic(
      schema_module,
      dyn,
      binding_alias,
      condition,
      key,
      value
    )
  end

  defp adapter!(opts) do
    if Keyword.has_key?(opts, :dynamic_expression_adapter) do
      opts[:dynamic_expression_adapter]
    else
      case find_adapter_for_repo(Config.repo!(opts).__adapter__(), opts) do
        nil -> @default_adapter
        {_, adapter_config} -> Keyword.fetch!(adapter_config, :adapter)
      end
    end
  end

  defp find_adapter_for_repo(repo_adapter, opts) do
    opts
    |> dynamic_expression_adapters()
    |> Enum.find(fn {key, _} -> key === repo_adapter end)
  end

  defp dynamic_expression_adapters(opts) do
    opts[:dynamic_expression_adapters] ||
      Config.dynamic_expression_adapters() ||
      @default_adapters
  end
end
