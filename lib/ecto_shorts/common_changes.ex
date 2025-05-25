defmodule EctoShorts.CommonChanges do
  @moduledoc """
  `EctoShorts.CommonChanges` provides helper functions to
  simplify working with Ecto changesets.

  This module focuses on making common tasks easier, such as
  handling the difference between `put_assoc/4` and
  `cast_assoc/3`, automatically preloading data when needed,
  and conditionally validating or transforming fields.

  For example, when working with nested associations, you can
  delegate the logic of choosing whether to cast or put the
  association based on how the input is shaped:

      def changeset(changeset, params) do
        changeset
        |> cast(params, [:name, :email])
        |> EctoShorts.CommonChanges.preload_change_assoc(:address)
      end

  You can also apply logic only when needed. For instance,
  if a field is nil and you want to provide a fallback value:

      EctoShorts.CommonChanges.put_when(
        &EctoShorts.CommonChanges.changeset_field_nil?(&1, :email),
        &put_change(&1, :email, "default@email.com")
      )

  Or you can require a related record based on whether a
  foreign key is missing:

      EctoShorts.CommonChanges.preload_change_assoc(
        changeset,
        :address,
        required_when_missing: :address_id
      )

  These utilities help keep your changeset logic clean,
  readable, and adaptable to a variety of input shapes
  without having to handle all edge cases manually.
  """

  alias Ecto.Changeset

  alias EctoShorts.{
    Actions,
    SchemaHelpers
  }

  @type changeset :: Ecto.Changeset.t()
  @type key :: atom()
  @type preloads :: atom() | list(atom()) | keyword()
  @type pattern :: binary() | Regex.t()
  @type precision :: :microsecond | :millisecond | :second
  @type opts :: keyword()

  @doc since: "2.5.0"
  @doc """
  Truncates a `NaiveDateTime` value in a field to a specified precision.

  ## Examples

      EctoShorts.CommonChanges.truncate_naive_datetime_change(changeset, :started_at)
  """
  @spec truncate_naive_datetime_change(changeset(), key(), precision()) :: changeset()
  def truncate_naive_datetime_change(changeset, key, precision \\ :second) do
    Changeset.update_change(changeset, key, fn
      datetime when is_struct(datetime, NaiveDateTime) ->
        NaiveDateTime.truncate(datetime, precision)

      term ->
        term
    end)
  end

  @doc since: "2.5.0"
  @doc """
  Truncates a `DateTime` value in a field to a specified precision.

  ## Examples

      EctoShorts.CommonChanges.truncate_datetime_change(changeset, :expires_at)
  """
  @spec truncate_datetime_change(changeset(), key(), precision()) :: changeset()
  def truncate_datetime_change(changeset, key, precision \\ :second) do
    Changeset.update_change(changeset, key, fn
      datetime when is_struct(datetime, DateTime) ->
        DateTime.truncate(datetime, precision)

      term ->
        term
    end)
  end

  @doc since: "2.5.0"
  @doc """
  Applies the given function if the field hasn’t already been changed.

  ## Example

      EctoShorts.CommonChanges.put_new_change(changeset, :slug, fn cs ->
        put_change(cs, :slug, generate_slug(cs))
      end)
  """
  @spec put_new_change(changeset(), key(), function()) :: changeset()
  def put_new_change(changeset, key, fun) do
    case Changeset.get_change(changeset, key) do
      nil -> fun.(changeset)
      _ -> changeset
    end
  end

  @doc """
  Applies a transformation function only if a condition is true.

  ## Example

      EctoShorts.CommonChanges.put_when(
        &EctoShorts.CommonChanges.changeset_field_empty?(&1, :tags),
        &put_change(&1, :tags, ["default"])
      )
  """
  @spec put_when(
          changeset(),
          (changeset() -> boolean()),
          (changeset() -> changeset())
        ) :: changeset()
  def put_when(changeset, when_func, func) do
    if when_func.(changeset) do
      func.(changeset)
    else
      changeset
    end
  end

  @doc since: "2.5.0"
  @doc """
  Returns true if the field on the changeset is an empty list or map.
  """
  @spec changeset_change_empty?(changeset(), key()) :: boolean()
  def changeset_change_empty?(changeset, key) do
    case Changeset.get_change(changeset, key) do
      change when is_list(change) -> change === []
      change when is_map(change) -> change === %{}
      _ -> false
    end
  end

  @doc since: "2.5.0"
  @doc """
  Returns true if the change for the given key is nil.
  """
  @spec changeset_change_nil?(changeset(), key()) :: boolean()
  def changeset_change_nil?(changeset, key) do
    changeset
    |> Changeset.get_change(key)
    |> is_nil()
  end

  @doc """
  Returns true if the field on the changeset is an empty list in
  the data or changes.

  ### Examples

      EctoShorts.CommonChanges.changeset_field_empty?(changeset, :comments)
  """
  @spec changeset_field_empty?(changeset(), key()) :: boolean()
  def changeset_field_empty?(changeset, key) do
    case Changeset.get_field(changeset, key) do
      change when is_list(change) -> change === []
      change when is_map(change) -> change === %{}
      _ -> false
    end
  end

  @doc """
  Returns true if the field on the changeset is nil in the data or changes.

  ### Examples

      EctoShorts.CommonChanges.changeset_field_nil?(changeset, :comments)
  """
  @spec changeset_field_nil?(changeset(), key()) :: boolean()
  def changeset_field_nil?(changeset, key) do
    changeset
    |> Changeset.get_field(key)
    |> is_nil()
  end

  @doc """
  Shortcut version of `preload_change_assoc/3` that uses default options.

  Only preloads and casts if the key is present in the params. Otherwise,
  falls back to a regular `cast_assoc/3`.
  """
  @spec preload_change_assoc(changeset(), key()) :: changeset()
  def preload_change_assoc(changeset, key) do
    if changeset_params_has_key?(changeset, key) do
      changeset
      |> preload_changeset_assoc(key)
      |> put_or_cast_assoc(key)
    else
      Changeset.cast_assoc(changeset, key)
    end
  end

  @doc """
  Preloads an association if present in the changeset params and
  applies either `cast_assoc/3` or `put_assoc/3`, depending on
  the data shape.

  This function allows direct usage of embedded maps or structs
  in the params without requiring manual preload in your
  controller or context logic.

  ## Options

    * `:required` - If set to `true`, validates that the association is not `nil`.

    * `:required_when_missing` - If the given field is `nil` in both `:changes`
      and `:data`, `:required` will be set to `true`.

    * `:repo` - Optional. Overrides the default repo used for preloading.

  ## Example

      EctoShorts.CommonChanges.preload_change_assoc(changeset, :profile)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :account, required: true)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :settings, required_when_missing: :settings_id)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :tags, repo: MyApp.CustomRepo)
  """
  @spec preload_change_assoc(changeset(), key(), opts()) :: changeset()
  def preload_change_assoc(changeset, key, opts) do
    required? =
      if opts[:required_when_missing] do
        changeset_field_nil?(changeset, opts[:required_when_missing])
      else
        opts[:required] === true
      end

    opts = Keyword.put(opts, :required, required?)

    if changeset_params_has_key?(changeset, key) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  @doc """
  Preloads the specified association onto the changeset `data`
  before calling `put_assoc/3` or `cast_assoc/3`. This is used
  internally by `preload_change_assoc/3` when a key is present
  in the changeset params.

  If the `:ids` option is provided, the association is loaded using
  `Actions.all/3` and matched by those IDs. Otherwise, it uses the
  configured or provided Repo to preload the association.

  ## Options

    * `:ids` - A list of IDs to fetch the associated records directly.
    * `:repo` - An optional custom Repo module to override default repo resolution.

  This is useful when working with nested input data that must be hydrated
  into structs before being validated.
  """
  @spec preload_changeset_assoc(changeset(), preloads()) :: changeset()
  @spec preload_changeset_assoc(changeset(), preloads(), opts()) :: changeset()
  def preload_changeset_assoc(changeset, preloads, opts \\ []) do
    Map.update!(changeset, :data, &Actions.preload(&1, preloads, opts))
  end

  def association_not_loaded?(%{data: schema_data} = _changeset, key) do
    SchemaHelpers.association_not_loaded?(schema_data, key)
  end

  def changeset(%{data: _} = changeset, params) when params === %{} or params === [] do
    changeset
  end

  def changeset(%{data: %{__meta__: %{schema: schema}}} = changeset, params) do
    changeset(schema, changeset, params)
  end

  def changeset(%{__meta__: %{schema: schema}} = schema_data, params) do
    changeset(schema, schema_data, params)
  end

  def changeset(schema, params) when is_atom(schema) do
    changeset(schema, struct(schema), params)
  end

  def changeset(schema, struct_or_changeset, params) do
    if function_exported?(schema, :changeset, 2) do
      schema.changeset(struct_or_changeset, params)
    else
      Changeset.change(struct_or_changeset, params)
    end
  end

  @doc """
  Determines how to apply an association change based on the shape
  of the input in `changeset.params[key]`.

  This function decides whether to use `put_assoc/4` or `cast_assoc/3`
  depending on what kind of data was passed in. This makes it easier
  to work with many-to-many relationships, nested data, or lists of IDs.

  ## Behavior

    * If given a list of structs, it uses `put_assoc/4`.
    * If given a list of maps with only `:id` fields, it fetches from the DB and replaces the relation.
    * If given a list of maps with new data, it preloads the existing relation and uses `cast_assoc/3`.
    * If given a single struct, it uses `put_assoc/4`.
    * Otherwise, it defaults to `cast_assoc/3`.

  ## Example

      EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :tags)
  """
  @spec put_or_cast_assoc(changeset(), key()) :: changeset()
  @spec put_or_cast_assoc(changeset(), key(), opts()) :: changeset()
  def put_or_cast_assoc(%{data: %{__meta__: _}} = changeset, key, opts \\ []) do
    params_data = get_changeset_params(changeset, key)

    apply_put_or_cast_assoc(changeset, key, params_data, opts)
  end

  defp apply_put_or_cast_assoc(changeset, key, nil, opts) do
    Changeset.cast_assoc(changeset, key, opts)
  end

  defp apply_put_or_cast_assoc(changeset, key, params_data, opts) when is_list(params_data) do
    schema = get_changeset_schema(changeset)

    cond do
      SchemaHelpers.all_schema_struct?(params_data) ->
        Changeset.put_assoc(changeset, key, params_data, opts)

      SchemaHelpers.all_only_primary_key?(schema, params_data) ->
        put_assoc(changeset, key, params_data, opts)

      SchemaHelpers.any_created?(schema, params_data) ->
        cast_assoc(changeset, key, params_data, opts)

      true ->
        Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_put_or_cast_assoc(changeset, key, params_data, opts) do
    if SchemaHelpers.schema_struct?(params_data) do
      Changeset.put_assoc(changeset, key, params_data, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  @doc """
  ...
  """
  def put_assoc(changeset, key, opts) do
    put_assoc(changeset, key, get_changeset_params(changeset, key), opts)
  end

  defp put_assoc(changeset, _key, nil, _opts) do
    changeset
  end

  defp put_assoc(changeset, key, params_data, opts) do
    assoc = fetch_changeset_association!(changeset, key)

    assoc_schema =
      if has_related_key?(assoc) do
        assoc.related
      else
        raise_not_related_assoc!(changeset, key, assoc)
      end

    related_key = assoc.related_key
    owner_value = Map.fetch!(changeset.data, assoc.owner_key)

    owner_params = if is_nil(owner_value), do: %{}, else: %{related_key => owner_value}
    query_params = build_assoc_query_params(assoc_schema, params_data, owner_params)

    if query_params === %{} do
      changeset
    else
      changeset = preload_association(changeset, key, opts)

      records = repo_all(assoc_schema, query_params, opts)

      Changeset.put_assoc(changeset, key, records, opts)
    end
  end

  @doc """
  ...
  """
  def cast_assoc(changeset, key, opts) do
    cast_assoc(changeset, key, get_changeset_params(changeset, key), opts)
  end

  defp cast_assoc(changeset, _key, nil, _opts) do
    changeset
  end

  defp cast_assoc(changeset, key, params_data, opts) do
    assoc = fetch_changeset_association!(changeset, key)

    assoc_schema =
      if has_related_key?(assoc) do
        assoc.related
      else
        raise_not_related_assoc!(changeset, key, assoc)
      end

    related_key = assoc.related_key
    owner_value = Map.fetch!(changeset.data, assoc.owner_key)

    owner_params = if is_nil(owner_value), do: %{}, else: %{related_key => owner_value}
    query_params = build_assoc_query_params(assoc_schema, params_data, owner_params)

    if query_params === %{} do
      changeset
    else
      changeset
      |> load_association(key, assoc_schema, query_params, opts)
      |> Changeset.cast_assoc(key, opts)
    end
  end

  defp build_assoc_query_params(assoc_schema, params_data, owner_params) do
    params_list =
      params_data
      |> List.wrap()
      |> Enum.reject(&is_struct/1)
      |> SchemaHelpers.filter_primary_key(assoc_schema)

    if SchemaHelpers.primary_key_count(assoc_schema) > 1 do
      if params_list === [] do
        owner_params
      else
        Map.put(owner_params, :or_where, params_list)
      end
    else
      params_list
      |> flatten_query_params()
      |> Map.merge(owner_params)
    end
  end

  defp flatten_query_params(params_data) do
    Enum.reduce(params_data, %{}, fn params, acc ->
      Enum.reduce(params, acc, fn
        {key, val}, acc when is_binary(val) or is_integer(val) ->
          Map.update(acc, key, [val], &[val | &1])

        _, acc ->
          acc
      end)
    end)
  end

  defp load_association(changeset, key, assoc_schema, query_params, opts) do
    records = repo_all(assoc_schema, query_params, opts)

    put_loaded_association(changeset, key, records, opts)
  end

  defp repo_all(schema, params, opts) do
    extra_params =
      if Keyword.has_key?(opts, :query_parameters) do
        case opts[:query_parameters] do
          nil -> %{}
          fun when is_function(fun, 0) -> fun.()
          value -> value
        end
      else
        %{}
      end

    params = Map.merge(extra_params, params)

    Actions.all(schema, params, opts)
  end

  defp put_loaded_association(changeset, key, records, opts) do
    Map.update!(changeset, :data, fn schema_data ->
      if SchemaHelpers.association_not_loaded?(schema_data, key) do
        Map.put(schema_data, key, records)
      else
        if Keyword.get(opts, :replace_association, true) do
          Map.put(schema_data, key, records)
        else
          schema_data
        end
      end
    end)
  end

  defp preload_association(changeset, key, opts) do
    if association_not_loaded?(changeset, key) or opts[:force_preload] === true do
      Map.update!(changeset, :data, fn schema_data ->
        Actions.preload(schema_data, key, opts)
      end)
    else
      changeset
    end
  end

  defp changeset_params_has_key?(%{params: nil}, _key), do: false
  defp changeset_params_has_key?(%{params: params}, key), do: Map.has_key?(params, to_string(key))

  defp get_changeset_params(%{params: nil}, _key), do: nil
  defp get_changeset_params(%{params: params}, key), do: Map.get(params, to_string(key))

  defp has_related_key?(%{related: _}), do: true
  defp has_related_key?(_), do: false

  defp raise_not_related_assoc!(%{data: %{__meta__: %{schema: schema}}} = changeset, key, assoc) do
    raise ArgumentError,
          """
          Expected a direct association with a `:related` key, but got
          an association that does not support direct Ecto operations.

          This likely happens when using a `:through` association,
          which cannot be used with functions like `put_assoc` or
          `cast_assoc`.

          Supported associations include: `belongs_to`, `has_one`, and `has_many`.

          schema:

          #{inspect(schema)}

          key:

          #{inspect(key)}

          association:

          #{inspect(assoc, pretty: true)}

          changeset:

          #{inspect(changeset, pretty: true)}
          """
  end

  defp fetch_changeset_association!(%{types: types} = changeset, key) do
    schema = get_changeset_schema(changeset)

    if Map.has_key?(types, key) do
      case Map.get(types, key) do
        {:assoc, assoc} ->
          assoc

        _ ->
          raise ArgumentError,
                "expected #{inspect(key)} to be an association in the changeset for schema #{inspect(schema)}"
      end
    else
      raise ArgumentError,
            "association #{inspect(key)} not found in the changeset for schema #{inspect(schema)}"
    end
  end

  defp get_changeset_schema(%{data: %{__meta__: %{schema: queryable}}}) do
    queryable
  end
end
