defmodule EctoShorts.CommonChanges do
  @moduledoc """
  Changeset helpers for building `changeset/2` functions in Ecto schemas.

  Use this module when building changeset pipelines that need to handle
  associations, apply conditional logic, validate field state, or coerce
  values. All functions accept an `Ecto.Changeset` and return an
  `Ecto.Changeset`, making them composable in changeset pipelines.

  ## Add helpers to a changeset

  Preload and cast an association:

      def changeset(user, params) do
        user
        |> cast(params, [:name, :email])
        |> validate_required([:name, :email])
        |> EctoShorts.CommonChanges.preload_change_assoc(:address)
      end

  Apply conditional changes:

      def changeset(post, params) do
        post
        |> cast(params, [:title, :slug])
        |> EctoShorts.CommonChanges.apply_when(
          &EctoShorts.CommonChanges.field_nil?(&1, :slug),
          &put_change(&1, :slug, generate_slug(&1))
        )
      end

  Validate fields are not unset:

      def changeset(user, params) do
        user
        |> cast(params, [:email, :name])
        |> EctoShorts.CommonChanges.validate_not_unset(:email)
      end

  ## When to use changeset helpers

  Use this module when you need to:

  * **Manage associations** - preload and cast associations in one step,
    handling both `put_assoc` and `cast_assoc` automatically.
  * **Apply conditional logic** - run changeset functions only when certain
    conditions are met.
  * **Validate field state** - ensure fields are not being unset or check
    for nil/empty values.
  * **Coerce values** - trim strings, truncate datetimes, or apply other
    transformations to field changes.
  * **Set defaults** - put values only when fields are nil or unchanged.

  ## Association management workflow

  The association management functions follow this workflow:

  1. **Check params** - determine if the association key is in params.
  2. **Preload if needed** - load existing data if the association is not
     already preloaded.
  3. **Choose strategy** - select `put_assoc` or `cast_assoc` based on the
     params value type.
  4. **Apply changes** - call the chosen function with the changeset.

  ### Basic association preloading

  Use `preload_change_assoc/3` to handle the common case:

      def changeset(user, params) do
        user
        |> cast(params, [:name])
        |> preload_change_assoc(:posts)
      end

  This preloads `:posts` if needed, then calls `cast_assoc/3`.

  ### Required associations

  Require that an association is provided:

      def changeset(user, params) do
        user
        |> cast(params, [:name])
        |> preload_change_assoc(:address, required: true)
      end

  ### Conditional requirement

  Require an association only when its foreign key is missing:

      def changeset(order, params) do
        order
        |> cast(params, [:total, :user_id])
        |> preload_change_assoc(:user, required_when_missing: :user_id)
      end

  This requires `:user` to be provided when `:user_id` is nil.

  ### Member updates

  Replace an association with specific records by ID:

      params = %{
        "fruits" => [%{"id" => 1}, %{"id" => 3}]
      }

      changeset(user, params)
      # Replaces user.fruits with fruits 1 and 3

  `put_or_cast_assoc/3` detects this pattern and uses `put_assoc/3`
  automatically.

  ## Conditional changes

  Use `apply_when/3` to run a changeset function only when a condition is met:

      def changeset(post, params) do
        post
        |> cast(params, [:title, :published_at])
        |> apply_when(
          &field_nil?(&1, :published_at),
          &put_change(&1, :published_at, DateTime.utc_now())
        )
      end

  The condition function receives the changeset and must return a boolean.
  The change function receives the changeset and must return a changeset.

  ### Common condition patterns

  **Check if a field is nil:**

      apply_when(
        changeset,
        &field_nil?(&1, :slug),
        &put_change(&1, :slug, generate_slug(&1))
      )

  **Check if a field has no change:**

      apply_when(
        changeset,
        &change_nil?(&1, :status),
        &put_change(&1, :status, :draft)
      )

  **Check if a field is empty:**

      apply_when(
        changeset,
        &field_empty?(&1, :tags),
        &put_change(&1, :tags, ["uncategorized"])
      )

  ## Field validation

  Use `validate_not_unset/2` to prevent fields from being set to nil:

      def changeset(user, params) do
        user
        |> cast(params, [:email, :name])
        |> validate_not_unset(:email)
      end

  This adds a `"can't be blank"` error when `:email` is being changed from
  a non-nil value to nil.

  ### When to use validate_not_unset

  * **Prevent accidental deletion** - ensure required fields cannot be
    cleared once set.
  * **Enforce business rules** - prevent users from removing critical data.
  * **Protect audit trails** - ensure tracking fields cannot be unset.

  ## Value coercion

  ### Trim strings

  Remove leading and trailing whitespace:

      def changeset(post, params) do
        post
        |> cast(params, [:title, :slug])
        |> trim_string_change([:title, :slug])
      end

  ### Truncate datetimes

  Truncate datetime precision:

      def changeset(event, params) do
        event
        |> cast(params, [:starts_at])
        |> truncate_datetime_change(:starts_at, :second)
      end

  This is useful when your database stores datetimes at second precision
  but Elixir defaults to microsecond precision.

  ## Default values

  ### Put change only if nil

  Use `put_new_change/3` to set a default only when there is no pending change:

      def changeset(post, params) do
        post
        |> cast(params, [:title, :status])
        |> put_new_change(:status, :draft)
      end

  ### Put change only if field is nil

  Use `put_new_value/3` to set a default only when the field is nil:

      def changeset(user, params) do
        user
        |> cast(params, [:name, :role])
        |> put_new_value(:role, :member)
      end

  This checks both the pending change and the persisted value.

  ### Dynamic defaults

  Pass a function to compute the default:

      def changeset(post, params) do
        post
        |> cast(params, [:title, :slug])
        |> put_new_change(:slug, fn _ -> generate_slug(post.title) end)
      end

  ## Changeset inspection

  ### Check for nil changes

  Use `change_nil?/2` to check if a field has no pending change:

      if change_nil?(changeset, :title) do
        # No title change pending
      end

  ### Check for empty changes

  Use `change_empty?/2` to check if a field change is empty:

      if change_empty?(changeset, :tags) do
        # Tags change is [] or %{}
      end

  ### Check field values

  Use `field_nil?/2` to check if a field is nil:

      if field_nil?(changeset, :published_at) do
        # Field is nil in data or changes
      end

  Use `field_empty?/2` to check if a field is an empty list:

      if field_empty?(changeset, :comments) do
        # Field is [] in data or changes
      end

  ## Common patterns

  **Pattern 1: Auto-generate slug from title**

      def changeset(post, params) do
        post
        |> cast(params, [:title, :slug])
        |> apply_when(
          &field_nil?(&1, :slug),
          fn cs ->
            title = get_field(cs, :title)
            put_change(cs, :slug, slugify(title))
          end
        )
      end

  **Pattern 2: Set published_at on status change**

      def changeset(post, params) do
        post
        |> cast(params, [:status, :published_at])
        |> apply_when(
          fn cs -> get_change(cs, :status) == :published end,
          &put_new_change(&1, :published_at, DateTime.utc_now())
        )
      end

  **Pattern 3: Require association or foreign key**

      def changeset(order, params) do
        order
        |> cast(params, [:total, :user_id])
        |> preload_change_assoc(:user, required_when_missing: :user_id)
      end

  **Pattern 4: Normalize string fields**

      def changeset(user, params) do
        user
        |> cast(params, [:email, :name])
        |> trim_string_change([:email, :name])
        |> update_change(:email, &String.downcase/1)
      end

  **Pattern 5: Prevent field deletion**

      def changeset(user, params) do
        user
        |> cast(params, [:email, :verified_at])
        |> validate_not_unset(:verified_at)
      end

  See also `EctoShorts.CommonSchema`, `EctoShorts.Actions`, and
  `EctoShorts.SchemaHelpers`.
  """

  @moduledoc groups: [
               %{
                 title: "Changeset inspection",
                 description: "Read or check changeset field state."
               },
               %{
                 title: "Changeset mutation",
                 description: "Apply conditional or coercive changes."
               },
               %{title: "Association management", description: "Preload and cast associations."}
             ]

  alias Ecto.Changeset
  alias EctoShorts.{Actions, Config, SchemaHelpers}

  @doc since: "3.0.0"
  @doc group: "Changeset inspection"
  @doc """
  Returns `true` if the given field (or all fields in a list) have no pending change.

  Checks `Ecto.Changeset.get_change/2` for each field. Returns `true` when
  the change is `nil` (i.e. no change was cast). When `fields` is a list,
  returns `true` only if **all** fields have a `nil` change.

  Use `field_nil?/2` when you need to check the current value (data or changes)
  rather than whether a pending change exists.

  ## Examples

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{})
      ...> EctoShorts.CommonChanges.change_nil?(changeset, :title)
      true

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{}, title: "Hello")
      ...> EctoShorts.CommonChanges.change_nil?(changeset, :title)
      false

  See also `change_empty?/2` and `field_nil?/2`.
  """
  @spec change_nil?(Ecto.Changeset.t(), atom() | list(atom())) :: boolean()
  def change_nil?(changeset, fields) when is_list(fields) do
    Enum.all?(fields, &change_nil?(changeset, &1))
  end

  def change_nil?(changeset, field) do
    changeset
    |> Changeset.get_change(field)
    |> is_nil()
  end

  @doc since: "3.0.0"
  @doc group: "Changeset inspection"
  @doc """
  Returns `true` if the given field (or all fields in a list) have an empty change.

  A change is considered empty when it is `[]` or `%{}`. Fields with `nil`
  changes or non-empty values return `false`. When `fields` is a list,
  returns `true` only if **all** fields have an empty change.

  Use `field_empty?/2` when you need to check the current value (data or changes)
  rather than whether a pending change is empty.

  ## Examples

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{}, comments: [])
      ...> EctoShorts.CommonChanges.change_empty?(changeset, :comments)
      true

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{})
      ...> EctoShorts.CommonChanges.change_empty?(changeset, :comments)
      false

  See also `change_nil?/2` and `field_empty?/2`.
  """
  @spec change_empty?(Ecto.Changeset.t(), atom() | list(atom())) :: boolean()
  def change_empty?(changeset, fields) when is_list(fields) do
    Enum.all?(fields, &change_empty?(changeset, &1))
  end

  def change_empty?(changeset, field) do
    case Changeset.get_change(changeset, field) do
      [] -> true
      map when map === %{} -> true
      _ -> false
    end
  end

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Prevents a field (or list of fields) from being set to `nil` when the field
  already has a persisted value.

  Adds a `"can't be blank"` error to the changeset when the field is
  being changed to `nil` from a non-nil persisted value. Does nothing when
  the field is already `nil` or has not changed.

  ## Examples

      iex> cs = Ecto.Changeset.cast(%EctoShorts.Schema.Post{title: "Old"}, %{title: nil}, [:title])
      ...> cs = EctoShorts.CommonChanges.validate_not_unset(cs, :title)
      ...> cs.errors[:title]
      {"can't be blank", []}

  See also `put_new_change/3` and `field_nil?/2`.
  """
  @spec validate_not_unset(Ecto.Changeset.t(), atom() | list(atom())) :: Ecto.Changeset.t()
  def validate_not_unset(changeset, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, acc_changeset ->
      validate_not_unset(acc_changeset, field)
    end)
  end

  def validate_not_unset(changeset, field) do
    original = Map.get(changeset.data, field)

    # skip if field is nil
    # check if field is being set to nil
    # skip if already errored
    should_error? =
      original !== nil and
        Changeset.changed?(changeset, field, to: nil) and
        not Keyword.has_key?(changeset.errors, field)

    if should_error? do
      Changeset.add_error(changeset, field, "can't be blank")
    else
      changeset
    end
  end

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Truncates datetime changes on the given field(s) to the specified precision.

  Accepts `:second`, `:millisecond`, or `:microsecond` as `precision`.
  Works on both `DateTime` and `NaiveDateTime` values. Non-datetime values
  are passed through unchanged.

  ## Examples

      iex> dt = ~U[2024-01-01 12:00:00.123456Z]
      ...> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{}, inserted_at: dt)
      ...> cs = EctoShorts.CommonChanges.truncate_datetime_change(cs, :inserted_at, :second)
      ...> Ecto.Changeset.get_change(cs, :inserted_at).microsecond
      {0, 6}

  See also `trim_string_change/2`.
  """
  @spec truncate_datetime_change(
          Ecto.Changeset.t(),
          atom() | list(atom()),
          :second | :millisecond | :microsecond
        ) ::
          Ecto.Changeset.t()
  def truncate_datetime_change(changeset, fields, precision \\ :second)

  def truncate_datetime_change(changeset, fields, precision) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, acc_changeset ->
      truncate_datetime_change(
        acc_changeset,
        field,
        precision
      )
    end)
  end

  def truncate_datetime_change(changeset, field, precision) do
    Changeset.update_change(changeset, field, fn
      %DateTime{} = datetime -> DateTime.truncate(datetime, precision)
      %NaiveDateTime{} = naive_datetime -> NaiveDateTime.truncate(naive_datetime, precision)
      value -> value
    end)
  end

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Trims leading and trailing whitespace from string changes on the given field(s).

  Accepts a single field atom or a list. Non-string change values are passed
  through unchanged.

  ## Examples

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{}, title: "  Hello  ")
      ...> cs = EctoShorts.CommonChanges.trim_string_change(cs, :title)
      ...> Ecto.Changeset.get_change(cs, :title)
      "Hello"

  See also `truncate_datetime_change/3` and `put_new_change/3`.
  """
  @spec trim_string_change(Ecto.Changeset.t(), atom() | list(atom())) :: Ecto.Changeset.t()
  def trim_string_change(changeset, fields) do
    fields
    |> List.wrap()
    |> Enum.reduce(changeset, fn field, acc_changeset ->
      Changeset.update_change(acc_changeset, field, fn
        change when is_binary(change) -> String.trim(change)
        value -> value
      end)
    end)
  end

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Puts a change only if the field has no pending change.

  This is change-based: it uses `Ecto.Changeset.get_change/2` to check for a
  pending change. See `put_new_value/3` for the value-based variant, which
  also considers the persisted value in `changeset.data`.

  `value` can be a literal value, a 0-arity function (called to produce the
  value), or a 1-arity function that receives the field name.

  ## Examples

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{})
      ...> cs = EctoShorts.CommonChanges.put_new_change(cs, :title, "Default")
      ...> Ecto.Changeset.get_change(cs, :title)
      "Default"

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{}, title: "Existing")
      ...> cs = EctoShorts.CommonChanges.put_new_change(cs, :title, "Default")
      ...> Ecto.Changeset.get_change(cs, :title)
      "Existing"

  See also `put_new_value/3` and `apply_when/3`.
  """
  @spec put_new_change(Ecto.Changeset.t(), atom(), term()) :: Ecto.Changeset.t()
  def put_new_change(changeset, field, value) do
    if Changeset.get_change(changeset, field) === nil do
      Changeset.put_change(
        changeset,
        field,
        resolve_value(value, field)
      )
    else
      changeset
    end
  end

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Puts a change only if the field's current value (data or changes) is `nil`.

  This is value-based: it uses `Ecto.Changeset.get_field/2` which reads the
  current value from changes first, then falls back to data. See
  `put_new_change/3` for the change-based variant, which only checks pending
  changes.

  `value` can be a literal value, a 0-arity function, or a 1-arity function
  that receives the field name.

  ## Examples

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{title: nil})
      ...> cs = EctoShorts.CommonChanges.put_new_value(cs, :title, "Default")
      ...> Ecto.Changeset.get_change(cs, :title)
      "Default"

  See also `put_new_change/3` and `apply_when/3`.
  """
  @spec put_new_value(Ecto.Changeset.t(), atom(), term()) :: Ecto.Changeset.t()
  def put_new_value(changeset, field, value) do
    if Changeset.get_field(changeset, field) === nil do
      Changeset.put_change(
        changeset,
        field,
        resolve_value(value, field)
      )
    else
      changeset
    end
  end

  defp resolve_value(fun, field) when is_function(fun, 1), do: fun.(field)
  defp resolve_value(fun, _) when is_function(fun, 0), do: fun.()
  defp resolve_value(value, _), do: value

  @doc since: "3.0.0"
  @doc group: "Changeset mutation"
  @doc """
  Applies `change_func` to the changeset only when `when_func` returns `true`.

  `when_func` is a 1-arity function that receives the changeset and must
  return a boolean. `change_func` is a 1-arity function that receives the
  changeset and must return a changeset.

  Raises `ArgumentError` when `change_func` returns a non-changeset value.

  ## Examples

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{title: nil})
      ...> changeset = EctoShorts.CommonChanges.apply_when(
      ...>   changeset,
      ...>   &EctoShorts.CommonChanges.field_nil?(&1, :title),
      ...>   &Ecto.Changeset.put_change(&1, :title, "Fallback")
      ...> )
      ...> Ecto.Changeset.get_change(changeset, :title)
      ...> "Fallback"

  See also `put_new_change/3`, `put_new_value/3`, and `change_nil?/2`.
  """
  @spec apply_when(
          Ecto.Changeset.t(),
          (Ecto.Changeset.t() -> boolean()),
          (Ecto.Changeset.t() -> Ecto.Changeset.t())
        ) :: Ecto.Changeset.t()
  def apply_when(changeset, when_func, change_func) do
    if when_func.(changeset) do
      case change_func.(changeset) do
        changeset when is_struct(changeset, Changeset) ->
          changeset

        term ->
          raise ArgumentError, "Expected function to return a changeset, got: #{inspect(term)}"
      end
    else
      changeset
    end
  end

  @doc group: "Changeset inspection"
  @doc """
  Returns `true` if the field on the changeset is an empty list in the data or changes.

  Uses `Ecto.Changeset.get_field/2` which reads the current value from
  changes first, then falls back to data.

  Use `change_empty?/2` when you need to check whether a pending change
  (not the current value) is empty.

  ## Examples

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{comments: []})
      ...> EctoShorts.CommonChanges.field_empty?(cs, :comments)
      true

  See also `field_nil?/2` and `change_empty?/2`.
  """
  @spec field_empty?(Changeset.t(), atom) :: boolean
  def field_empty?(changeset, key) do
    Changeset.get_field(changeset, key) === []
  end

  @doc group: "Changeset inspection"
  @doc """
  Returns `true` if the field on the changeset is `nil` in the data or changes.

  Uses `Ecto.Changeset.get_field/2` which reads from changes first, then
  falls back to data.

  Use `change_nil?/2` when you need to check whether a pending change exists
  (not the current value).

  ## Examples

      iex> cs = Ecto.Changeset.change(%EctoShorts.Schema.Post{title: nil})
      ...> EctoShorts.CommonChanges.field_nil?(cs, :title)
      true

  See also `field_empty?/2` and `change_nil?/2`.
  """
  @spec field_nil?(Changeset.t(), atom) :: boolean
  def field_nil?(changeset, key) do
    changeset |> Changeset.get_field(key) |> is_nil()
  end

  @doc group: "Association management"
  @doc """
  Preloads a changeset association if needed, then puts or casts it.

  This is the primary helper for managing associations in `changeset/2`
  functions. When the association key is present in `changeset.params`,
  it preloads the existing data so `cast_assoc/3` can diff correctly.
  When absent, falls back to `Ecto.Changeset.cast_assoc/3`.

  Internally this function preloads the association data, then calls
  `put_or_cast_assoc/3` when the association is present in params. For most
  use cases this is the only function you need.

  ## Options

  * `:required_when_missing` - sets `:required` to `true` when the given
    field is `nil` in both changes and data. Use this to require that either
    an association or its foreign key is provided.
  * `:required` - when `true`, validates that the association is present.
    For one-to-one associations a non-nil value suffices; for many associations
    a non-empty list is required. See `Ecto.Changeset.cast_assoc/3` for details.
    Defaults to `false`.
  * `:repo` - the `Ecto.Repo` to use for the preload query. Defaults to
    `EctoShorts.Config.repo/0`.

  ## Examples

      iex> EctoShorts.CommonChanges.preload_change_assoc(changeset, :comments)
      iex> EctoShorts.CommonChanges.preload_change_assoc(changeset, :comments, required: true)
      iex> EctoShorts.CommonChanges.preload_change_assoc(changeset, :comments,
      ...>   required_when_missing: :author_id
      ...> )

  See also `put_or_cast_assoc/3`.
  """
  @spec preload_change_assoc(Changeset.t(), atom(), keyword()) :: Changeset.t()
  def preload_change_assoc(changeset, key, opts \\ []) do
    required? =
      if opts[:required_when_missing] do
        field_nil?(changeset, opts[:required_when_missing])
      else
        opts[:required] === true
      end

    opts = Keyword.put(opts, :required, required?)

    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  @doc false
  @spec preload_changeset_assoc(Changeset.t(), atom) :: Changeset.t()
  @spec preload_changeset_assoc(Changeset.t(), atom, keyword()) :: Changeset.t()
  def preload_changeset_assoc(changeset, key, opts \\ [])

  def preload_changeset_assoc(changeset, key, opts) do
    if opts[:ids] do
      schema = changeset_relationship_schema(changeset, key)

      records = Actions.all(schema, %{ids: opts[:ids]}, opts)

      Map.update!(changeset, :data, &Map.put(&1, key, records))
    else
      Map.update!(changeset, :data, &Config.repo!(opts).preload(&1, key, opts))
    end
  end

  defp changeset_relationship_schema(changeset, key) do
    if Map.has_key?(changeset.types, key) and relationship_exists?(changeset.types[key]) do
      {:assoc, assoc} = Map.get(changeset.types, key)

      assoc.queryable
    else
      %parent_schema{} = changeset.data

      raise ArgumentError,
            "The key #{inspect(key)} is not an association for the queryable #{inspect(parent_schema)}."
    end
  end

  @doc group: "Association management"
  @doc """
  Chooses between `put_assoc` and `cast_assoc` based on the params value.

  Inspects the raw value in `changeset.params` for the given `key` and
  selects the appropriate strategy:

  * When params contains a list of schema structs - `put_assoc`.
  * When params contains a list of `%{id: id}` maps only (member update) -
    loads the matching records and calls `put_assoc`.
  * When params contains a list with some persisted IDs - preloads existing
    records and calls `cast_assoc`.
  * Otherwise - `cast_assoc`.

  You typically do not call this directly - use `preload_change_assoc/3`
  which preloads the association data then calls this function in one step.

  ## Examples

      # Params contain plain maps → cast_assoc
      changeset = Ecto.Changeset.cast(user, %{"comments" => [%{"body" => "hi"}]}, [])
      EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :comments)

      # Params contain schema structs → put_assoc
      changeset = Ecto.Changeset.change(user, %{"comments" => [%Comment{id: 1, body: "hi"}]})
      EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :comments)

      # Params contain only %{id: id} maps → queries records and put_assoc
      changeset = Ecto.Changeset.change(user, %{"fruits" => [%{"id" => 1}, %{"id" => 3}]})
      EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :fruits)

  See also `preload_change_assoc/3`.
  """
  @spec put_or_cast_assoc(Changeset.t(), atom) :: Changeset.t()
  @spec put_or_cast_assoc(Changeset.t(), atom, Keyword.t()) :: Changeset.t()
  def put_or_cast_assoc(changeset, key, opts \\ []) do
    params_data = Map.get(changeset.params, Atom.to_string(key))

    find_method_and_put_or_cast(changeset, key, params_data, opts)
  end

  defp find_method_and_put_or_cast(changeset, key, nil, opts) do
    Changeset.cast_assoc(changeset, key, opts)
  end

  defp find_method_and_put_or_cast(changeset, key, params_data, opts) when is_list(params_data) do
    cond do
      SchemaHelpers.all_schema_struct?(params_data) ->
        Changeset.put_assoc(
          changeset,
          key,
          params_data,
          opts
        )

      member_update?(params_data) ->
        schema = changeset_relationship_schema(changeset, key)
        data = Actions.all(schema, %{ids: data_ids(params_data)})
        Changeset.put_assoc(changeset, key, data, opts)

      SchemaHelpers.any_persisted?(params_data) ->
        ids = params_data |> data_ids() |> Enum.reject(&is_nil/1)

        changeset
        |> preload_changeset_assoc(key, Keyword.put(opts, :ids, ids))
        |> Changeset.cast_assoc(key, opts)

      true ->
        Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp find_method_and_put_or_cast(changeset, key, param_data, opts) do
    if SchemaHelpers.schema_struct?(param_data) do
      Changeset.put_assoc(changeset, key, param_data, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp member_update?([]), do: false

  defp member_update?(schemas) do
    Enum.all?(schemas, fn
      %{id: id} = item when item === %{id: id} -> true
      _ -> false
    end)
  end

  defp data_ids(data), do: Enum.map(data, &Map.get(&1, :id))

  defp relationship_exists?({:assoc, _}), do: true
  defp relationship_exists?(_), do: false
end
