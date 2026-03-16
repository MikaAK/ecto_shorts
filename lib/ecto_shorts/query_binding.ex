defmodule EctoShorts.QueryBinding do
  @moduledoc """
  Compile-time query binding contracts and AST helpers.

  This module provides two things:

  1. **Binding contracts** - `query_binding_contracts/2` generates the
     exhaustive set of Ecto query binding patterns for a given module at
     compile time. Each filter sub-module calls this at the top level of
     its body so that Elixir emits one function clause per binding shape
     (root binding, named binding, and up to `n` positional bindings).
     This is the mechanism that lets EctoShorts handle `{:as, name}` and
     `{:at, index}` selectors without runtime branching inside every hot
     code path.

  2. **AST helpers** - a collection of functions that produce quoted
     Elixir AST fragments used inside `defmacro`-free `quote/unquote`
     blocks inside the dynamic expression sub-modules.  They keep the
     expression builders readable by naming the construction of pinned
     variables, special-form operators, and `dynamic/2` wrapper calls.

  ## Compile-time usage

      # At module body level - generates binding patterns once:
      {target_binding_var, binding_patterns} =
        EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)

      for {binding_head, binding_body} <- binding_patterns do
        def my_clause(unquote(binding_head), value) do
          Query.where(query, [unquote_splicing(binding_body)], ^value)
        end
      end

  ## Configuration

  The maximum number of positional bindings is controlled by
  `EctoShorts.Config.max_positional_bindings/0` (default: `10`). This
  determines how many `{:at, index}` patterns are generated. Increasing
  this value increases compile time linearly but allows deeper join
  chains.
  """

  @default_max_positional_bindings 10

  @doc """
  Generates binding patterns for a query binding module at compile time.

  Returns `{target_binding_var, binding_patterns}` where:

    * `target_binding_var` is the `Macro.var/2` quote for the `q` variable
      scoped to `context`.
    * `binding_patterns` is a list of `{binding_head, binding_body}` pairs
      covering:
      - `{:as, nil}` - root/default binding
      - `{:as, name}` - named binding
      - `{:at, 1}` through `{:at, n}` - positional bindings

  ## Arguments

    * `context` - the calling module atom, used to scope generated variables
      so they do not leak across modules. Defaults to `__MODULE__`.
    * `opts` - keyword options:
      * `:positions` - override the maximum positional binding count.

  ## Options

    * `:positions` - the number of positional bindings to create.

  ## Examples

      {target_var, patterns} = EctoShorts.QueryBinding.query_binding_contracts(__MODULE__, positions: 3)
      length(patterns)
      # => 5  (nil-as, named-as, at-1, at-2, at-3)
  """
  @spec query_binding_contracts(atom(), keyword()) :: Macro.t()
  def query_binding_contracts(context \\ __MODULE__, opts \\ []) do
    max_positional_bindings = opts[:positions] || @default_max_positional_bindings

    target_binding_var = Macro.var(:q, context)
    binding_alias_var = Macro.var(:binding_alias, context)
    step_var = Macro.var(:_, context)

    binding_patterns =
      [
        {{:as, nil}, [target_binding_var]},
        {{:as, binding_alias_var},
         [
           quote do
             {^unquote(binding_alias_var), unquote(target_binding_var)}
           end
         ]}
      ] ++
        Enum.map(1..max_positional_bindings, fn index ->
          {{:at, index}, positional_binding_vars(index, target_binding_var, step_var)}
        end)

    {target_binding_var, binding_patterns}
  end

  @doc """
  Wraps an AST expression in a `not` special form.

  Used to negate dynamic expressions when a `:not` modifier is present
  in the filter term.

  ## Examples

      EctoShorts.QueryBinding.negated_expr(quote do: x == 1)
      # => quote do: not (x == 1)
  """
  def negated_expr(expr) do
    quote do
      not unquote(expr)
    end
  end

  @doc """
  Builds a quoted AST node for a binary operator expression.

  Handles Elixir special forms (`in`, `==`, `!=`, comparison operators,
  and arithmetic operators) that cannot be produced with `apply/3` at
  compile time.

  ## Arguments

    * `left` - the left-hand side AST node.
    * `op` - an operator atom. Supported: `:in`, `:==`/`:eq`, `:!=`/`:ne`,
      `:>`/`:gt`, `:<`/`:lt`, `:>=`/`:gte`, `:<=`/`:lte`, `:+`, `:-`,
      `:*`, `:/`.
    * `right` - the right-hand side AST node.
  """
  def special_form_ast(left, :in, right) do
    quote do
      unquote(left) in unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:==, :eq] do
    quote do
      unquote(left) === unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:!=, :ne] do
    quote do
      unquote(left) !== unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:>, :gt] do
    quote do
      unquote(left) > unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:<, :lt] do
    quote do
      unquote(left) < unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:>=, :gte] do
    quote do
      unquote(left) >= unquote(right)
    end
  end

  def special_form_ast(left, op, right) when op in [:<=, :lte] do
    quote do
      unquote(left) <= unquote(right)
    end
  end

  def special_form_ast(left, :+, right) do
    quote do
      unquote(left) + unquote(right)
    end
  end

  def special_form_ast(left, :-, right) do
    quote do
      unquote(left) - unquote(right)
    end
  end

  def special_form_ast(left, :*, right) do
    quote do
      unquote(left) * unquote(right)
    end
  end

  def special_form_ast(left, :/, right) do
    quote do
      unquote(left) / unquote(right)
    end
  end

  @doc """
  Builds a quoted pin (`^var`) AST node.

  Used when a runtime variable must be pinned inside a `dynamic/2` or
  `Query.*` macro call.
  """
  def pinned_ast(var) do
    quote do
      ^unquote(var)
    end
  end

  @doc """
  Builds a `dynamic/2` call AST for the given binding selector.

  For `{:as, var}` selectors the generated code branches at runtime on
  whether `var` is `nil` (root binding) or an atom (named binding). For
  `{:at, index}` selectors it emits a positional binding list.

  ## Arguments

    * `selected_binding` - `{:as, target_var}` or `{:at, index}`.
    * `q_var` - the `Macro.var/2` for the query row variable.
    * `field_expr` - the inner field expression AST to wrap.
    * `context` - the calling module atom, used to scope the step variable
      for positional bindings.
  """
  def dyn_expr({:as, target_var}, q_var, field_expr, _context) do
    quote do
      if is_nil(unquote(target_var)) do
        dynamic([unquote(q_var)], unquote(field_expr))
      else
        dynamic([{^unquote(target_var), unquote(q_var)}], unquote(field_expr))
      end
    end
  end

  def dyn_expr({:at, index}, q_var, field_expr, context) do
    step_var = Macro.var(:_, context)
    query_binding_vars = positional_binding_vars(index, q_var, step_var)

    quote do
      dynamic([unquote_splicing(query_binding_vars)], unquote(field_expr))
    end
  end

  @doc """
  Builds the positional binding variable list for a given depth.

  Returns a list of AST variables where all entries before the last are
  the anonymous step variable `_` (to skip bindings) and the last entry
  is `q_var` (the target row variable).

  ## Examples

      step = Macro.var(:_, MyMod)
      q    = Macro.var(:q, MyMod)
      EctoShorts.QueryBinding.positional_binding_vars(1, q, step)  # => [q]
      EctoShorts.QueryBinding.positional_binding_vars(3, q, step)  # => [step, step, q]
  """
  def positional_binding_vars(index, q_var, step_var) when is_integer(index) and index >= 1 do
    if index === 1 do
      [q_var]
    else
      1..(index - 1)
      |> Enum.map(fn _ -> step_var end)
      |> Kernel.++([q_var])
    end
  end
end
