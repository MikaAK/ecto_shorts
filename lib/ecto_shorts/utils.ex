defmodule EctoShorts.Utils do
  @moduledoc false

  @type schema_data :: Ecto.Schema.t()
  @type acc :: any()
  @type callback :: (any(), any() -> any())
  @type opts :: keyword()

  @ordered_expressions false

  def all?([], _), do: false
  def all?(map, _) when map === %{}, do: false
  def all?(enum, fun), do: Enum.all?(enum, fun)

  def atomize_keys(enum, opts \\ []) do
    transform_keys(enum, &string_to_atom(&1, opts))
  end

  defp string_to_atom(value, opts) when is_binary(value) do
    case Keyword.get(opts, :to_existing_atom, true) do
      true -> String.to_existing_atom(value)
      false -> String.to_atom(value)
    end
  end

  defp string_to_atom(value, _opts) do
    value
  end

  def transform_keys({key, value}, fun) do
    {fun.(key), transform_keys(value, fun)}
  end

  def transform_keys([head | tail], fun) do
    [transform_keys(head, fun) | transform_keys(tail, fun)]
  end

  def transform_keys(params, fun) when is_map(params) do
    params
    |> Map.to_list()
    |> transform_keys(fun)
    |> Map.new()
  end

  def transform_keys(value, _fun) do
    value
  end

  @doc """
  Flattens the input data and applies a function to each key-value pair.

  This function traverses the entire structure of the given input, flattens
  it, and calls the given function for each result. You can use this to
  build up a value using an accumulator.

  Nested values are grouped under their top-level keys so you can retain
  context. For example:

      %{post: %{profile: %{age: 30}}}

  Will produce:

      [{:post, {:profile, {:age, 30}}}]

  ## Options

    * `:ordered_expressions` — if set to `true`, preserves the order of
      traversal. If `false` (default), order is not guaranteed but the
      operation is faster.

  ## Examples

      # Collect all key-value pairs into a list.

      iex> EctoShorts.Utils.apply_expressions(
      ...>   [],
      ...>   %{post: %{title: "hello_world"}, age: 30},
      ...>   fn pair, acc -> [pair | acc] end
      ...> )
      [
        {:post, {:title, "hello_world"}},
        {:age, 30}
      ]

      # Use it to build up a expression.

      iex> import Ecto.Query
      ...> EctoShorts.Utils.apply_expressions(
      ...>    EctoShorts.Schemas.Post,
      ...>    %{id: 1, title: "hello_world"},
      ...>    fn {key, val}, query ->
      ...>      from p in query, where: field(p, ^key) == ^val
      ...>    end
      ...> )
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.title == ^"hello_world", where: p0.id == ^1>

      # Structs are preserved as-is.

      iex> EctoShorts.Utils.apply_expressions(
      ...>   [],
      ...>   %{post: %EctoShorts.Schemas.Post{id: 1}},
      ...>   fn pair, acc -> [pair | acc] end
      ...> )
      [
        {:post, %EctoShorts.Schemas.Post{id: 1}}
      ]

      # Keyword lists are flattened.

      iex> EctoShorts.Utils.apply_expressions(
      ...>   [],
      ...>   [title: "hello", author: "admin"],
      ...>   fn pair, acc -> [pair | acc] end
      ...> )
      [
        {:title, "hello"},
        {:author, "admin"},
      ]

      # Non-keyword lists are preserved.

      iex> EctoShorts.Utils.apply_expressions(
      ...>   [],
      ...>   %{tags: ["elixir", "ecto"]},
      ...>   fn pair, acc -> [pair | acc] end
      ...> )
      [
        {:tags, ["elixir", "ecto"]}
      ]
  """
  @spec apply_expressions(acc(), any(), callback()) :: acc()
  @spec apply_expressions(acc(), any(), callback(), opts()) :: acc()
  def apply_expressions(acc, input, fun, opts \\ []) when is_function(fun, 2) do
    input
    |> flatten_input(opts)
    |> apply_transform_fun(acc, fun)
  end

  defp apply_transform_fun([], acc, _fun) do
    acc
  end

  defp apply_transform_fun([head | todo], acc, fun) do
    with acc <- fun.(head, acc) do
      apply_transform_fun(todo, acc, fun)
    end
  end

  defp flatten_input(input, opts) do
    with acc <- do_flatten(input, []) do
      if ordered_expressions?(opts) do
        Enum.reverse(acc)
      else
        acc
      end
    end
  end

  # stop expansion
  defp do_flatten([], acc) do
    acc
  end

  # flatten keyword lists
  defp do_flatten([{_, _} = head | tail] = _kwd, acc) do
    do_flatten(tail, do_flatten(head, acc))
  end

  # flatten single tuples
  defp do_flatten({key, %_{} = struct}, acc) do
    [{key, struct} | acc]
  end

  defp do_flatten({key, map}, acc) when is_map(map) do
    do_flatten({key, Map.to_list(map)}, acc)
  end

  # stop expansion
  defp do_flatten({_key, []}, acc) do
    acc
  end

  # flatten list of keyword tuples
  defp do_flatten({key, [{_, _} = head | tail]}, acc) do
    with acc <- do_flatten({key, head}, acc) do
      do_flatten({key, tail}, acc)
    end
  end

  # return any other value as-is
  defp do_flatten({key, val}, acc) do
    [{key, val} | acc]
  end

  # return structs as-is
  defp do_flatten(%_{} = struct, acc) do
    [struct | acc]
  end

  # flatten top-level maps
  defp do_flatten(map, acc) when is_map(map) do
    map
    |> Map.to_list()
    |> do_flatten(acc)
  end

  # for all other types include them as-is
  defp do_flatten(val, acc) do
    [val | acc]
  end

  defp ordered_expressions?(opts) do
    (opts[:ordered_expressions] || @ordered_expressions) === true
  end

  @doc """
  Converts an Ecto struct into a plain map that’s safe to encode as JSON.

  Removes internal Ecto metadata fields (`__meta__`, `__schema__`) and
  any associations defined on the schema. This results in a flat map
  containing only a subset of the struct's fields.

  ## Example

      iex> EctoShorts.Utils.to_jsonable_map(%EctoShorts.Schemas.Post{id: 1, title: "example"})
      %{
        id: 1,
        title: "example",
        body: nil,
        inserted_at: nil,
        notes: nil,
        permalink: nil,
        published: nil,
        tags: nil,
        updated_at: nil,
        user_id: nil,
        views: nil
      }
  """
  @spec to_jsonable_map(schema_data()) :: map()
  def to_jsonable_map(%{__meta__: %{schema: queryable}} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__schema__, :__meta__])
    |> Map.drop(queryable.__schema__(:associations))
  end

  @doc """
  Reduces an enumerable by applying a function that returns `{:ok, value}` or
  `{:error, reason}` to each item, accumulating successes and errors separately.

  If all elements return `{:ok, value}`, returns `{:ok, list_of_values}`.
  If any element returns `{:error, term}`, returns `{:error, list_of_terms}`.

  You can set the initial accumulator for successful values by `value_acc` or
  the initial accumulator for errors by `error_acc`.

  ### Examples

      iex> EctoShorts.Utils.reduce_all([1], fn v -> {:ok, v} end)
      {:ok, [1]}

      iex> EctoShorts.Utils.reduce_all(["error"], fn v -> {:error, v} end)
      {:error, ["error"]}
  """
  @spec reduce_all(enum :: Enum.t(), fun :: function()) :: {:ok, list()} | {:error, list()}
  def reduce_all(enum, fun) do
    case Enum.reduce(enum, {[], []}, &reduce_eval(&1, fun, &2)) do
      {values, []} -> {:ok, Enum.reverse(values)}
      {_, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp reduce_eval(term, fun, {values, errors}) do
    case fun.(term) do
      {:error, e} -> {values, [e | errors]}
      {:ok, v} -> {[v | values], errors}
      term -> raise "expected {:ok, term()} or {:error, term()}, got: #{inspect(term)}"
    end
  end

  def underscore_last_module_alias(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
