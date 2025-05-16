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
    data_or_nil = get_changeset_params(changeset, key)

    apply_put_or_cast_assoc(changeset, key, data_or_nil, opts)
  end

  defp apply_put_or_cast_assoc(changeset, key, nil, opts) do
    Changeset.cast_assoc(changeset, key, opts)
  end

  defp apply_put_or_cast_assoc(changeset, key, params_data, opts) when is_list(params_data) do
    schema_module = get_changeset_queryable(changeset)

    cond do
      SchemaHelpers.all_schema?(params_data) ->
        Changeset.put_assoc(changeset, key, params_data, opts)

      only_primary_keys?(schema_module, params_data) ->
        raise_if_not_association!(schema_module, key)

        assoc_schema_module = fetch_association_schema!(changeset, key)

        query_params = build_query_params(schema_module, params_data)

        query_params =
          if Keyword.has_key?(opts, :limit) do
            Map.put(query_params, :limit, opts[:limit])
          else
            query_params
          end

        records = Actions.all(assoc_schema_module, query_params, opts)

        Changeset.put_assoc(changeset, key, records, opts)

      SchemaHelpers.any_created?(schema_module, params_data) ->
        raise_if_not_association!(schema_module, key)

        assoc_schema_module = fetch_association_schema!(changeset, key)

        query_params = build_query_params(schema_module, params_data)

        query_params =
          if Keyword.has_key?(opts, :limit) do
            Map.put(query_params, :limit, opts[:limit])
          else
            query_params
          end

        records = Actions.all(assoc_schema_module, query_params, opts)

        changeset
        |> Map.update!(:data, fn schema_struct ->
          if SchemaHelpers.association_not_loaded?(schema_struct, key) do
            Map.put(schema_struct, key, records)
          else
            if opts[:force] === true do
              Map.put(schema_struct, key, records)
            else
              EctoShorts.Utils.Logger.warning(
                __MODULE__,
                "association key '#{inspect(key)}' for the schema '#{inspect(schema_module)}' already has loaded data."
              )

              schema_struct
            end
          end
        end)
        |> Changeset.cast_assoc(key, opts)

      true ->
        Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_put_or_cast_assoc(changeset, key, params_data, opts) do
    if SchemaHelpers.schema?(params_data) do
      Changeset.put_assoc(changeset, key, params_data, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp raise_if_not_association!(schema_module, key) do
    if key not in schema_module.__schema__(:associations) do
      raise ArgumentError,
            "key not found in schema #{inspect(schema_module)} associations, got: #{inspect(key)}"
    end
  end

  @doc false
  def changeset_params_has_key?(%{params: nil}, _key) do
    false
  end

  def changeset_params_has_key?(%{params: params}, key) do
    Map.has_key?(params, to_string(key))
  end

  @doc false
  def get_changeset_params(%{params: nil}, _key) do
    nil
  end

  def get_changeset_params(%{params: params}, key) do
    Map.get(params, to_string(key))
  end

  @doc false
  def build_query_params(schema_module, params_data) do
    case SchemaHelpers.primary_key(schema_module) do
      [_] ->
        schema_module
        |> SchemaHelpers.filter_primary_keys(params_data)
        |> flatten_query_params()

      _ -> %{or_where: SchemaHelpers.filter_primary_keys(schema_module, params_data)}
    end
  end

  @doc false
  def flatten_query_params(list_of_params) do
    Enum.reduce(list_of_params, %{}, fn params, acc ->
      Enum.reduce(params, acc, fn {key, value}, acc ->
        Map.update(acc, key, [value], &(&1 ++ [value]))
      end)
    end)
  end

  @doc false
  def only_primary_keys?(schema_module, params) when is_map(params) do
    SchemaHelpers.filter_primary_keys(schema_module, params) === params
  end

  def only_primary_keys?(schema_module, values) when is_list(values) do
    if Keyword.keyword?(values) do
      SchemaHelpers.filter_primary_keys(schema_module, values) === values
    else
      Enum.all?(values, fn params -> only_primary_keys?(schema_module, params) end)
    end
  end

  def only_primary_keys?(_schema_module, _term) do
    false
  end

  @doc false
  def fetch_association_schema!(changeset, key) do
    with :ok <- ensure_member_of_changeset_types!(changeset, key) do
      changeset
      |> fetch_changeset_assoc_type!(key)
      |> Map.fetch!(:queryable)
    end
  end

  @doc false
  def ensure_member_of_changeset_types!(changeset, key) do
    schema_module = get_changeset_queryable(changeset)

    if member_of_changeset_types?(changeset, key) do
      :ok
    else
      raise ArgumentError,
            "key not found in schema #{inspect(schema_module)} " <>
              "changeset types, got: #{inspect(key)}"
    end
  end

  @doc false
  def member_of_changeset_types?(%{types: types}, key) do
    Map.has_key?(types, key)
  end

  @doc false
  def fetch_changeset_assoc_type!(%{types: types} = changeset, key) do
    schema_module = get_changeset_queryable(changeset)

    case Map.get(types, key) do
      {:assoc, value} ->
        value

      _ ->
        raise KeyError,
              "key not found in schema #{inspect(schema_module)} " <>
                "changeset types, got: #{inspect(key)}"
    end
  end

  @doc false
  def get_changeset_queryable(%{data: %{__meta__: %{schema: queryable}}}) do
    queryable
  end
end
