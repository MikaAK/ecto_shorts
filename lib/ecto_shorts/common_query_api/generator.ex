defmodule EctoShorts.CommonQueryAPI.Generator do
  @moduledoc false
  alias EctoShorts.CommonQueryAPI.Generator

  @doc """
  Generates a set of query helper functions (wrappers around Ecto.Query macros)
  based on the provided options and injects them into the current module.

  This macro supports all major query macros (e.g., `dynamic`, `where`, `select`, `join`)
  and allows you to generate both positional and named binding variants.

  ## Options

    * `:max` - Max number of positional bindings to support (required)
    * `:prefix` - Atom prefix for generated binding vars (default: `:b`)
    * `:operators` - List of operator atoms to generate clauses for (e.g., `:==`, `:in`, `:ilike`)
    * `:builder` - Module implementing `build_expr/4` (and optionally `build_head_ast/4`)
    * `:reverse_ops` - Operators for which the key/value should be reversed

  ## Examples

  ### Example 1: Define dynamic/3 functions for `==`, `ilike`, `in`, and `fragment_like` (named binding support)

      EctoShorts.CommonQueryAPI.Generator.define_query_api(
        :dynamic,
        max: 3,
        builder: EctoShorts.CommonQueryAPI.Generator.FieldExprBuilder,
        operators: [:==, :ilike, :in, :fragment_like],
        reverse_ops: []
      )

  ### Example 2: Define join/6 wrappers for association and subquery joins

      EctoShorts.CommonQueryAPI.Generator.define_query_api(
        :join,
        max: 2,
        builder: EctoShorts.CommonQueryAPI.Generator.JoinExprBuilder,
        operators: [:association, :subquery]
      )
  """
  defmacro define_query_api(macro_name, opts \\ []) do
    query_api_ast = Generator.build_query_api_ast(macro_name, __CALLER__, opts)

    quote do
      unquote(query_api_ast)
    end
  end

  @doc """
  Returns quoted AST for all generated clauses for a given macro name.

  ## Used Internally By
    * `define_query_api/2`

  ## Options

    See `define_query_api/2` for full list of supported options.

  ## Examples

      # Build clauses for dynamic/3 with both named and positional variants
      EctoShorts.CommonQueryAPI.Generator.build_query_api_ast(
        :dynamic,
        __ENV__,
        max: 2,
        prefix: :b,
        builder: EctoShorts.CommonQueryAPI.Generator.FieldExprBuilder,
        operators: [:==, :in]
      )

      # Build only positional bindings for join/6
      EctoShorts.CommonQueryAPI.Generator.build_query_api_ast(
        :join,
        __ENV__,
        max: 2,
        builder: EctoShorts.CommonQueryAPI.Generator.JoinExprBuilder,
        operators: [:association, :subquery]
      )
  """
  def build_query_api_ast(macro_name, env \\ __ENV__, opts \\ []) do
    max = Keyword.fetch!(opts, :max)
    prefix = Keyword.get(opts, :prefix, :b)
    ops = Keyword.get(opts, :operators, [:ilike])
    builder = Keyword.fetch!(opts, :builder)

    positional_fns =
      for op <- ops, count <- 1..max do
        Generator.build_query_api_function_ast(
          builder,
          macro_name,
          {:positional, count},
          op,
          prefix,
          env,
          opts
        )
      end

    named_fns =
      for op <- ops do
        Generator.build_query_api_function_ast(
          builder,
          macro_name,
          :named,
          op,
          prefix,
          env,
          opts
        )
      end

    fn_asts = positional_fns ++ named_fns

    quote do
      (unquote_splicing(fn_asts))
    end
  end

  @doc """
  Builds a single function clause AST for a specific macro/operation combination.

  This function is the core of how the Generator creates query macro wrappers.
  It's called by `build_query_api_ast/3` to produce a single function clause.

  ## Parameters

    * `builder_module` - Module that implements `build_expr/4`
    * `macro_name` - The query macro to wrap (e.g., `:dynamic`, `:join`, `:select`)
    * `binding_arg` - Either `{:positional, n}` or `:named` to indicate binding style
    * `op` - The operation atom (e.g., `:==`, `:in`, `:association`, `:fragment_like`)
    * `prefix` - Prefix used when generating binding vars (default: `:b`)
    * `opts` - The keyword list of options passed from the generator macro

  ## Examples

      # Build AST for dynamic/3 using 2 positional bindings
      EctoShorts.CommonQueryAPI.Generator.build_query_api_function_ast(
        EctoShorts.CommonQueryAPI.Generator.FieldExprBuilder,
        :dynamic,
        {:positional, 2},
        :==,
        :b,
        __ENV__,
        []
      )

      # Build AST for join/6 using named binding
      EctoShorts.CommonQueryAPI.Generator.build_query_api_function_ast(
        EctoShorts.CommonQueryAPI.Generator.JoinExprBuilder,
        :join,
        :named,
        :association,
        :b,
        __ENV__,
        [hints: "use_index"]
      )
  """
  def build_query_api_function_ast(
        builder_module,
        macro_name,
        binding_arg,
        op,
        prefix \\ :b,
        env \\ __ENV__,
        opts \\ []
      ) do
    # Ensure builder_module is a real module atom (handles alias AST or literal atoms)
    builder_module =
      builder_module
      |> Macro.expand(env)
      |> case do
        {:__aliases__, _, aliases} -> Module.concat(aliases)
        atom when is_atom(atom) -> atom
      end

    {bindings, binding_var} = build_bindings(binding_arg, prefix, env)

    reverse_ops = Keyword.get(opts, :reverse_ops, [])
    reverse? = op in reverse_ops

    key_var = Macro.var(:key, env.context)
    value_var = Macro.var(:value, env.context)

    {key_var, value_var} = if reverse?, do: {value_var, key_var}, else: {key_var, value_var}

    inner_expr = builder_module.build_expr(op, bindings, key_var, value_var)

    query_var = Macro.var(:query, env.context)
    qual_var = Macro.var(:qual, env.context)
    opts_var = Macro.var(:opts, env.context)

    clause_head =
      build_clause_head(
        builder_module,
        macro_name,
        {op, query_var, qual_var, key_var, value_var, binding_var, opts_var}
      )

    macro_block =
      build_macro_block(macro_name, {binding_arg, bindings, inner_expr, opts_var}, opts)

    quote do
      def unquote(clause_head) do
        unquote(macro_block)
      end
    end
  end

  defp build_clause_head(
         builder_module,
         macro_name,
         {op, query_var, qual_var, key_var, value_var, binding_var, opts_var}
       ) do
    if function_exported?(builder_module, :build_head_ast, 4) do
      builder_module.build_head_ast(op, key_var, value_var, binding_var)
    else
      args =
        case macro_name do
          :join -> [query_var, binding_var, qual_var, key_var, {op, value_var}, opts_var]
          :dynamic -> [binding_var, key_var, {op, value_var}]
          _ -> [query_var, binding_var, key_var, {op, value_var}]
        end

      quote do
        unquote(macro_name)(unquote_splicing(args))
      end
    end
  end

  defp build_macro_block(:dynamic, {binding_arg, bindings, inner_expr, _opts_var}, _opts) do
    case binding_arg do
      {:positional, _} ->
        quote do
          Ecto.Query.dynamic([unquote_splicing(bindings)], unquote(inner_expr))
        end

      :named ->
        [{_, selected_binding_var}] = bindings

        quote do
          if binding_alias do
            Ecto.Query.dynamic([unquote_splicing(bindings)], unquote(inner_expr))
          else
            Ecto.Query.dynamic([unquote(selected_binding_var)], unquote(inner_expr))
          end
        end
    end
  end

  defp build_macro_block(:join, {binding_arg, bindings, inner_expr, opts_var}, opts) do
    join_opts =
      if Keyword.has_key?(opts, :hints) do
        hints = opts[:hints]

        quote do
          [on: ^on_expr, as: ^as, prefix: ^prefix, hints: unquote(hints)]
        end
      else
        quote do
          [on: ^on_expr, as: ^as, prefix: ^prefix]
        end
      end

    case binding_arg do
      {:positional, _} ->
        quote do
          on_expr = unquote(opts_var)[:on] || true
          as = unquote(opts_var)[:as]
          prefix = unquote(opts_var)[:prefix]

          Ecto.Query.join(
            query,
            qual,
            [unquote_splicing(bindings)],
            unquote(inner_expr),
            unquote(join_opts)
          )
        end

      :named ->
        [{_, selected_binding_var}] = bindings

        quote do
          on_expr = unquote(opts_var)[:on] || true
          as = unquote(opts_var)[:as]
          prefix = unquote(opts_var)[:prefix]

          if binding_alias do
            Ecto.Query.join(
              query,
              qual,
              [unquote_splicing(bindings)],
              unquote(inner_expr),
              unquote(join_opts)
            )
          else
            Ecto.Query.join(
              query,
              qual,
              [unquote(selected_binding_var)],
              unquote(inner_expr),
              unquote(join_opts)
            )
          end
        end
    end
  end

  defp build_macro_block(macro_name, {binding_arg, bindings, inner_expr, _opts_var}, _opts) do
    case binding_arg do
      {:positional, _} ->
        quote do
          Ecto.Query.unquote(macro_name)(
            query,
            [unquote_splicing(bindings)],
            unquote(inner_expr)
          )
        end

      :named ->
        [{_, selected_binding_var}] = bindings

        quote do
          if binding_alias do
            Ecto.Query.unquote(macro_name)(
              query,
              [unquote_splicing(bindings)],
              unquote(inner_expr)
            )
          else
            Ecto.Query.unquote(macro_name)(
              query,
              [unquote(selected_binding_var)],
              unquote(inner_expr)
            )
          end
        end
    end
  end

  defp build_bindings({:positional, binding_count}, prefix, env) do
    bindings =
      Enum.map(0..(binding_count - 1), fn i ->
        Macro.var(:"#{prefix}#{i}", env.context)
      end)

    {bindings, binding_count}
  end

  defp build_bindings(:named, prefix, env) do
    pinned_binding_alias_var = Macro.var(:"^binding_alias", env.context)
    binding_var = Macro.var(:"#{prefix}0", env.context)
    bindings = [{pinned_binding_alias_var, binding_var}]

    binding_head_var = Macro.var(:binding_alias, env.context)

    {bindings, binding_head_var}
  end
end
