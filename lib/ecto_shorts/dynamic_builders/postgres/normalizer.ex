defmodule EctoShorts.DynamicBuilders.Postgres.Normalizer do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Input normalization for the Postgres dynamic expression adapter.

  This module converts the flexible filter term shapes accepted by the
  public EctoShorts filter API into a canonical internal representation
  before expression building begins. The caller (`DynamicBuilders.Adapters.Postgres`)
  calls `normalize_params/3` to flatten and canonicalize the raw filter
  value, then dispatches each normalized entry to the appropriate
  expression builder.

  ## Supported input shapes

  Filter values may arrive in many shapes depending on how the caller
  constructed the params map:

    * Plain scalar values - passed through unchanged.
    * Maps (`%{field: value}`) - converted to keyword list form.
    * Keyword lists - iterated; each entry is normalized recursively.
    * Quantifier tuples (`{:all, payload}`, `{:any, payload}`) - kept
      as-is so the expression builder can handle subquery expansion.
    * Arithmetic value tuples (`{:+, [left, right]}`) - converted to
      `{op, {normalized_left, normalized_right}}`.
    * Datetime wrapper tuples (`{:datetime, payload}`, `{:date, payload}`)
      - payload is normalized and rewrapped.
    * Field/value marker tuples (`{:field, name}`, `{:value, v}`) -
      field name is atomized via `normalize_field_name/3`; value is
      normalized recursively.

  ## Field name normalization strategy

  String field names inside `%{field: "name"}` arithmetic operands are
  resolved to atoms using a three-tier strategy:

  1. **Schema present** - validate the string against the schema's field
     list (compared as strings, not atoms). Valid → `String.to_existing_atom/1`.
     Invalid → log a warning and return `nil`.

  2. **No schema, `:allowed_keys` option provided** - check membership in
     the caller-supplied list converted to a `MapSet`. Present →
     `String.to_atom/1`. Absent → log a warning and return `nil`.

  3. **Fallback** - attempt `String.to_existing_atom/1` and rescue
     `ArgumentError`. On failure → log a warning and return `nil`.

  Atom inputs are always passed through unchanged.

  ## Value node normalization

  `normalize_value_node/3` converts a single value node into its
  canonical form. It is called recursively by `normalize_params/3` and
  by itself for nested structures.
  """

  alias EctoShorts.CommonSchema

  @quantifier_operators [:all, :any]
  @arithmetic_value_operators [:+, :-, :*, :/]
  @datetime_wrappers [:datetime, :date]
  @datetime_value_operators [:add, :ago, :from_now]

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres.Normalizer"

  @doc """
  Normalizes a raw filter term into a flat list of canonical entries.

  Each element of the returned list is one of:

    * `{key, value}` - a field/operator pair ready for expression building.
    * `{:and, {key, value}}` / `{:or, {key, value}}` - a merge-operator
      tagged pair produced by `normalize_keyword_params/3`.
    * `{quantifier, payload}` - a quantifier operator pair.

  `source` is the queryable source (schema module, table name string, or
  `Ecto.Query`). `opts` is the standard options keyword list. Both are
  forwarded to `normalize_field_name/3` during field reference resolution.

  ## Examples

      iex> Normalizer.normalize_params(nil, %{views: 5}, [])
      [{:views, 5}]

      iex> Normalizer.normalize_params(nil, true, [])
      [true]
  """
  @spec normalize_params(term(), term(), keyword()) :: list()
  def normalize_params(source, term, opts) do
    cond do
      is_map(term) and not is_struct(term) ->
        term
        |> Map.to_list()
        |> then(&normalize_params(source, &1, opts))

      Keyword.keyword?(term) ->
        normalize_keyword_params(source, term, [], opts)

      true ->
        [normalize_value_node(source, term, opts)]
    end
  end

  @doc """
  Normalizes a keyword list of filter params into a flat list.

  Entries that are quantifier operators or arithmetic/datetime wrappers
  are preserved with their structure. Other entries are recursively
  normalized by calling `normalize_params/3` on their value, then each
  resulting entry is re-paired with the original key.
  """
  @spec normalize_keyword_params(term(), list(), list(), keyword()) :: list()
  def normalize_keyword_params(_source, [], acc, _opts), do: Enum.reverse(acc)

  def normalize_keyword_params(source, [head | tail], acc, opts) do
    with acc2 <- normalize_keyword_params(source, head, acc, opts) do
      normalize_keyword_params(source, tail, acc2, opts)
    end
  end

  def normalize_keyword_params(_source, {quantifier, payload}, acc, _opts)
      when quantifier in @quantifier_operators do
    [{quantifier, payload} | acc]
  end

  def normalize_keyword_params(source, {:arithmetic, params}, acc, opts) do
    [normalize_arithmetic(source, params, opts) | acc]
  end

  def normalize_keyword_params(_source, {:aggregate, params}, acc, _opts) do
    [normalize_aggregate(params) | acc]
  end

  def normalize_keyword_params(source, {:elements, inner_term}, acc, opts) do
    [{:elements, normalize_params(source, inner_term, opts)} | acc]
  end

  def normalize_keyword_params(source, {op, inner_term}, acc, opts)
      when op in @arithmetic_value_operators do
    [normalize_value_node(source, {op, inner_term}, opts) | acc]
  end

  def normalize_keyword_params(source, {wrapper, inner_term}, acc, opts)
      when wrapper in @datetime_wrappers do
    [normalize_value_node(source, {wrapper, inner_term}, opts) | acc]
  end

  def normalize_keyword_params(source, {key, inner_term}, acc, opts) do
    prepend_key(key, normalize_params(source, inner_term, opts), acc)
  end

  @doc """
  Normalizes a single value node into its canonical form.

  Handles the full range of value shapes: plain scalars, maps, keyword
  lists with `:field`/`:value` markers, arithmetic expressions, datetime
  wrappers, and datetime operation nodes.

  `source` and `opts` are forwarded to `normalize_field_name/3` when a
  `{:field, name}` node is encountered. Passing `nil` for `source` and
  `[]` for `opts` gives the same fallback behaviour as the old 1-arity
  version.

  ## Examples

      iex> Normalizer.normalize_value_node(nil, {:+, [1, 2]}, [])
      {:+, {1, 2}}

      iex> Normalizer.normalize_value_node(nil, :something, [])
      :something
  """
  @spec normalize_value_node(term(), term(), keyword()) :: term()
  def normalize_value_node(source, term, opts) when is_map(term) and not is_struct(term) do
    term
    |> Map.to_list()
    |> then(&normalize_value_node(source, &1, opts))
  end

  def normalize_value_node(source, {:field, field_name}, opts) do
    {:field, normalize_field_name(source, field_name, opts)}
  end

  def normalize_value_node(source, {:value, value}, opts) do
    {:value, normalize_value_node(source, value, opts)}
  end

  def normalize_value_node(source, {op, term}, opts) when op in @arithmetic_value_operators do
    case term do
      [left, right] ->
        {op,
         {normalize_value_node(source, left, opts), normalize_value_node(source, right, opts)}}

      _ ->
        raise ArgumentError,
              "Expected arithmetic operator value to be a two-element list [left, right], got: #{inspect(term)}"
    end
  end

  def normalize_value_node(source, {wrapper, term}, opts) when wrapper in @datetime_wrappers do
    case normalize_datetime_wrapper_payload(source, term, opts) do
      {datetime_op, datetime_term} when datetime_op in @datetime_value_operators ->
        {wrapper, {datetime_op, datetime_term}}

      _ ->
        raise ArgumentError,
              "Expected datetime wrapper payload to be a keyword or map with a datetime operation key (:add, :ago, :from_now), got: #{inspect(term)}"
    end
  end

  def normalize_value_node(source, {op, term}, opts) when op in @datetime_value_operators do
    {op, normalize_datetime_node(source, term, opts)}
  end

  def normalize_value_node(source, [{:field, field_name}], opts) do
    {:field, normalize_field_name(source, field_name, opts)}
  end

  def normalize_value_node(source, [{:value, value}], opts) do
    {:value, normalize_value_node(source, value, opts)}
  end

  def normalize_value_node(_source, [], _opts) do
    []
  end

  def normalize_value_node(source, [head | tail], opts) do
    [normalize_value_node(source, head, opts) | normalize_value_node(source, tail, opts)]
  end

  def normalize_value_node(_source, term, _opts), do: term

  @doc """
  Normalizes a datetime wrapper payload (the value inside `{:datetime, ...}`
  or `{:date, ...}`).

  Accepts a map or a single-entry keyword list whose key is a datetime
  operation (`:add`, `:ago`, `:from_now`). Returns the normalized
  `{op, term}` pair.

  Raises `ArgumentError` for unrecognized shapes.
  """
  @spec normalize_datetime_wrapper_payload(term(), term(), keyword()) :: {atom(), term()}
  def normalize_datetime_wrapper_payload(source, term, opts)
      when is_map(term) and not is_struct(term) do
    term
    |> Map.to_list()
    |> then(&normalize_datetime_wrapper_payload(source, &1, opts))
  end

  def normalize_datetime_wrapper_payload(source, term, opts) when is_list(term) do
    if Keyword.keyword?(term) do
      case term do
        [{datetime_op, datetime_term}] when datetime_op in @datetime_value_operators ->
          normalize_value_node(source, {datetime_op, datetime_term}, opts)

        _ ->
          raise ArgumentError,
                "Expected datetime wrapper payload to be a single-key keyword list with one of #{inspect(@datetime_value_operators)}, got: #{inspect(term)}"
      end
    else
      raise ArgumentError,
            "Expected datetime wrapper payload to be a keyword list or map, got: #{inspect(term)}"
    end
  end

  @doc """
  Normalizes a datetime operation node (`{:add, ...}`, `{:ago, ...}`,
  `{:from_now, ...}`).

  Accepts a map or keyword list with `:count`, `:interval`, and
  optionally `:field` keys. Returns a keyword list in canonical order.

  Raises `ArgumentError` if the input is not a keyword list or map.
  """
  @spec normalize_datetime_node(term(), term(), keyword()) :: keyword()
  def normalize_datetime_node(source, term, opts) when is_map(term) and not is_struct(term) do
    term
    |> Map.to_list()
    |> then(&normalize_datetime_node(source, &1, opts))
  end

  def normalize_datetime_node(source, term, opts) when is_list(term) do
    if Keyword.keyword?(term) do
      field_name = Keyword.get(term, :field)
      count = Keyword.fetch!(term, :count)
      interval = Keyword.fetch!(term, :interval)

      base = maybe_put_datetime_field(source, field_name, [], opts)
      base ++ [count: count, interval: interval]
    else
      raise ArgumentError,
            "Expected datetime params to be a keyword list or map, got: #{inspect(term)}"
    end
  end

  @doc """
  Normalizes a short-form operator alias to its canonical long-form symbol.

      iex> Normalizer.normalize_operator(:eq)
      :==
      iex> Normalizer.normalize_operator(:>=)
      :>=
  """
  @spec normalize_operator(atom()) :: atom()
  def normalize_operator(:eq), do: :==
  def normalize_operator(:ne), do: :!=
  def normalize_operator(:gt), do: :>
  def normalize_operator(:gte), do: :>=
  def normalize_operator(:lt), do: :<
  def normalize_operator(:lte), do: :<=
  def normalize_operator(:downcase), do: :lower
  def normalize_operator(:upcase), do: :upper
  def normalize_operator(op), do: op

  def normalize_field_name(_source, field_name, _opts) when is_atom(field_name), do: field_name

  def normalize_field_name(source, field_name, opts) when is_binary(field_name) do
    case (source !== nil && CommonSchema.get_schema(source) !== nil &&
            CommonSchema.get_schema_reflection(source, :fields)) || nil do
      fields when is_list(fields) ->
        string_fields = MapSet.new(fields, &Atom.to_string/1)

        if MapSet.member?(string_fields, field_name) do
          String.to_existing_atom(field_name)
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Field \"#{field_name}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
          )

          nil
        end

      _ ->
        allowed_keys = opts[:allowed_keys]

        if allowed_keys do
          allowed_set = MapSet.new(allowed_keys)

          if MapSet.member?(allowed_set, field_name) do
            String.to_atom(field_name)
          else
            EctoShorts.Logger.warning(
              @logger_prefix,
              "Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"
            )

            nil
          end
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Field \"#{field_name}\" cannot be resolved: no schema or :allowed_keys available, skipping field reference"
          )

          nil
        end
    end
  end

  defp prepend_key(_key, [], acc), do: acc

  defp prepend_key(key, [normalized_term | rest], acc) do
    prepend_key(key, rest, [{key, normalized_term} | acc])
  end

  defp maybe_put_datetime_field(_source, nil, params, _opts), do: params

  defp maybe_put_datetime_field(source, field_name, params, opts) do
    [{:field, normalize_field_name(source, field_name, opts)} | params]
  end

  # Aggregate: {fn: :avg, compare: :>, value: 5} → {:avg, {:>, 5}}
  defp normalize_aggregate(params) when is_map(params) and not is_struct(params) do
    normalize_aggregate(Map.to_list(params))
  end

  defp normalize_aggregate(params) when is_list(params) do
    agg_fn = Keyword.fetch!(params, :fn)
    compare_op = normalize_operator(Keyword.fetch!(params, :compare))
    value = Keyword.fetch!(params, :value)
    {agg_fn, {compare_op, value}}
  end

  # Arithmetic: dispatches to numeric or datetime branch based on presence of :interval.
  defp normalize_arithmetic(source, params, opts) when is_map(params) and not is_struct(params) do
    normalize_arithmetic(source, Map.to_list(params), opts)
  end

  defp normalize_arithmetic(source, params, opts) when is_list(params) do
    compare_op = normalize_operator(Keyword.fetch!(params, :compare))
    {arith_key, operand} = find_arithmetic_operation(params)

    operand_map =
      if is_map(operand) and not is_struct(operand), do: Map.to_list(operand), else: operand

    if Keyword.keyword?(operand_map) and Keyword.has_key?(operand_map, :interval) do
      normalize_datetime_arithmetic(source, compare_op, arith_key, operand_map, opts)
    else
      normalize_numeric_arithmetic(source, compare_op, arith_key, operand_map, opts)
    end
  end

  # Finds the operation key (:add, :subtract, :multiply, :divide, :ago, :from_now)
  # and its operand payload from an arithmetic params list.
  defp find_arithmetic_operation(params) do
    Enum.find_value(params, fn
      {:add, operand} -> {:add, operand}
      {:subtract, operand} -> {:subtract, operand}
      {:multiply, operand} -> {:multiply, operand}
      {:divide, operand} -> {:divide, operand}
      {:ago, operand} -> {:ago, operand}
      {:from_now, operand} -> {:from_now, operand}
      _ -> nil
    end)
  end

  # Numeric arithmetic: operation key → internal symbol, operand → {left, right} pair.
  defp normalize_numeric_arithmetic(source, compare_op, arith_key, operand, opts) do
    internal_op = numeric_op_to_internal(arith_key)
    operands = normalize_arithmetic_operands(source, operand, opts)
    {compare_op, {:value, {internal_op, operands}}}
  end

  defp numeric_op_to_internal(:add), do: :+
  defp numeric_op_to_internal(:subtract), do: :-
  defp numeric_op_to_internal(:multiply), do: :*
  defp numeric_op_to_internal(:divide), do: :/

  # Converts {:field, name} and {:value, v} operand pairs to the internal form.
  defp normalize_arithmetic_operands(source, operand, opts) when is_list(operand) do
    field_name = Keyword.get(operand, :field)
    value = Keyword.get(operand, :value)
    left = if field_name, do: {:field, normalize_field_name(source, field_name, opts)}, else: nil
    right = if value != nil, do: {:value, value}, else: nil
    {left, right}
  end

  defp normalize_arithmetic_operands(_source, operand, _opts), do: operand

  # Datetime arithmetic: routes to the internal datetime/date wrapper form.
  # cast: :date in the operand payload triggers the :date wrapper; default is :datetime.
  defp normalize_datetime_arithmetic(source, compare_op, datetime_op, operand, opts) do
    cast = Keyword.get(operand, :cast, :datetime)
    operand_without_cast = Keyword.delete(operand, :cast)
    params = normalize_datetime_node(source, operand_without_cast, opts)
    {compare_op, {cast, {datetime_op, params}}}
  end
end
