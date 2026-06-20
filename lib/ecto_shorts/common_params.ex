defmodule EctoShorts.CommonParams do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Prepares data for `c:Ecto.Repo.insert_all/3` and `c:Ecto.Repo.update_all/3`.

  Use this module when you need to perform bulk inserts or updates with Ecto.
  It transforms application-level data (maps, structs, changesets) into the
  format Ecto expects, handles validation, generates timestamps, manages
  placeholders, and builds conflict resolution options.

  ## Prepare params for bulk operations

  Convert params to insert format:

      params = [
        %{title: "First post", published: true},
        %{title: "Second post", published: false}
      ]

      {:ok, inserts} =
        EctoShorts.CommonParams.convert_to_insert_params(
          EctoShorts.Schema.Post,
          params
        )

      Repo.insert_all(EctoShorts.Schema.Post, inserts)

  Build conflict resolution options:

      conflict_opts =
        EctoShorts.CommonParams.build_on_conflict_options(
          EctoShorts.Schema.Post,
          inserts,
          []
        )

      Repo.insert_all(EctoShorts.Schema.Post, inserts, conflict_opts)

  Convert params to update format:

      updates =
        EctoShorts.CommonParams.convert_to_update_params(
          EctoShorts.Schema.Post,
          %{title: "Updated", views: {:inc, 1}}
        )

      Repo.update_all(query, updates)

  ## Insert params workflow

  The insert params workflow follows these steps:

  1. **Normalize** - convert each entry to a map or struct.
  2. **Validate** - run through the schema's `changeset/2` (optional).
  3. **Filter** - keep only fields in the schema's query fields.
  4. **Enrich** - add `:inserted_at` and `:updated_at` timestamps.
  5. **Substitute** - replace placeholder values with `{:placeholder, field}`.

  ### Step 1: Normalize

  Each entry can be a map, keyword list, struct, changeset, or
  `{struct, params}` tuple:

      # Map:
      %{title: "Hello", published: true}

      # Keyword list:
      [title: "Hello", published: true]

      # Struct:
      %Post{title: "Hello", published: true}

      # Changeset:
      Ecto.Changeset.change(%Post{}, %{title: "Hello"})

      # Tuple:
      {%Post{id: 1}, %{title: "Updated"}}

  All forms are normalized to a struct, then converted to a map.

  ### Step 2: Validate

  By default, each entry runs through the schema's `changeset/2` function
  for validation. If validation fails, the entry is added to the error list
  and the function returns `{:error, [changeset, ...]}`.

  Skip validation by passing `validate: false`:

      EctoShorts.CommonParams.convert_to_insert_params(
        Post,
        params,
        validate: false
      )

  When validation is skipped, structs are built directly without calling
  `changeset/2`.

  ### Step 3: Filter

  Only fields in the schema's query fields are kept. Query fields are
  determined by `schema.__schema__(:query_fields)` or the `:query_fields`
  option.

  ### Step 4: Enrich

  Timestamps are added automatically:

  * `:inserted_at` - set to the current UTC time.
  * `:updated_at` - set to the current UTC time.

  Override the timestamp values or field names with options:

      EctoShorts.CommonParams.convert_to_insert_params(
        Post,
        params,
        inserted_at: ~U[2026-01-01 00:00:00Z],
        inserted_at_source: :created_on
      )

  ### Step 5: Substitute

  Placeholder values are replaced with `{:placeholder, field}` tuples for
  use with `c:Ecto.Repo.insert_all/3`'s `:placeholders` option.

  See the "Placeholder options" section for details.

  ## Update params workflow

  The update params workflow follows these steps:

  1. **Parse** - convert each `{field, value}` pair to an operation.
  2. **Group** - group operations by type (`:set`, `:inc`, `:push`, `:pull`).
  3. **Enrich** - add `:updated_at` to the `:set` group.

  ### Step 1: Parse

  Each value can be a plain value (`:set` is implied) or a tagged tuple:

      %{title: "New title"}                # {:set, :title, "New title"}
      %{views: {:inc, 1}}                  # {:inc, :views, 1}
      %{tags: {:push, "elixir"}}           # {:push, :tags, "elixir"}
      %{tags: {:pull, "deprecated"}}       # {:pull, :tags, "deprecated"}

  ### Step 2: Group

  Operations are grouped by type:

      [
        inc: [views: 1],
        set: [title: "New title", updated_at: ...]
      ]

  ### Step 3: Enrich

  The `:updated_at` field is added to the `:set` group automatically.

  ## Conflict resolution strategies

  Use `build_on_conflict_options/3` to generate `:conflict_target` and
  `:on_conflict` options for `c:Ecto.Repo.insert_all/3`.

  | Strategy         | Behaviour                                     |
  |------------------|----------------------------------------------|
  | `:insert_keys`   | Replace all non-primary-key fields (default) |
  | `:none`          | Insert or do nothing (no update on conflict) |
  | `[field, ...]`   | Replace only the listed fields               |

  Set the strategy with the `:on_conflict_replace` option:

      # Replace all non-primary-key fields:
      EctoShorts.CommonParams.build_on_conflict_options(
        Post,
        inserts,
        on_conflict_replace: :insert_keys
      )

      # Insert or do nothing:
      EctoShorts.CommonParams.build_on_conflict_options(
        Post,
        inserts,
        on_conflict_replace: :none
      )

      # Replace only specific fields:
      EctoShorts.CommonParams.build_on_conflict_options(
        Post,
        inserts,
        on_conflict_replace: [:title, :body]
      )

  ## Placeholder options

  Placeholders let you reference values from the `:placeholders` option in
  `c:Ecto.Repo.insert_all/3`. This is useful when you want to insert the
  same value across multiple rows without repeating it.

  | Option                      | Purpose                                      |
  |-----------------------------|----------------------------------------------|
  | `:placeholders`             | Map of `{field, value}` pairs to substitute  |
  | `:on_placeholder_conflict`  | What to do when a value conflicts            |

  ### Basic placeholder usage

  Pass a map of placeholder values:

      EctoShorts.CommonParams.convert_to_insert_params(
        Post,
        [%{author_id: 1}, %{author_id: 1}],
        placeholders: %{author_id: 1}
      )

  Fields matching the placeholder value are replaced with
  `{:placeholder, field}`:

      [
        %{author_id: {:placeholder, :author_id}},
        %{author_id: {:placeholder, :author_id}}
      ]

  Then pass the placeholders to `insert_all/3`:

      Repo.insert_all(Post, inserts, placeholders: %{author_id: 1})

  ### Placeholder conflict handling

  When a field value does not match the placeholder value, the
  `:on_placeholder_conflict` option controls what happens:

  * `:nothing` (default) - keep the existing value unchanged.
  * `:replace_all` - always use the placeholder regardless of conflict.
  * `{:replace, [field, ...]}` - only replace the listed fields.

  Example:

      EctoShorts.CommonParams.convert_to_insert_params(
        Post,
        [%{author_id: 1}, %{author_id: 2}],
        placeholders: %{author_id: 1},
        on_placeholder_conflict: :replace_all
      )

  Both rows will use the placeholder even though the second row has a
  different value.

  ## Validation

  By default, `convert_to_insert_params/3` validates each entry through the
  schema's `changeset/2` function. This catches validation errors before
  the insert.

  ### When to validate

  * **Validate** when the data comes from user input and needs validation.
  * **Skip validation** when the data is already validated or comes from a
    trusted source (for example, seeding data or internal migrations).

  ### Validation failures

  When validation fails, the function returns `{:error, [changeset, ...]}`:

      {:error, [changeset]} =
        EctoShorts.CommonParams.convert_to_insert_params(
          Post,
          [%{title: nil}]  # title is required
        )

      changeset.errors
      # [title: {"can't be blank", [validation: :required]}]

  ### Skipping validation

  Pass `validate: false` to skip validation:

      {:ok, inserts} =
        EctoShorts.CommonParams.convert_to_insert_params(
          Post,
          [%{title: "Hello"}],
          validate: false
        )

  ## Troubleshooting

  **Problem:** `convert_to_insert_params/3` returns `{:error, [changeset]}`.

  **Solution:** Check the changeset errors to see which validations failed.
  Fix the input data or adjust the schema's `changeset/2` function.

  **Problem:** Timestamps are not being added.

  **Solution:** Verify the schema has `:inserted_at` and `:updated_at`
  fields defined with `timestamps()` in the schema.

  **Problem:** Fields are missing from the insert data.

  **Solution:** Check that the fields are in the schema's query fields.
  Use `:query_fields` option to override.

  **Problem:** Placeholder substitution is not working.

  **Solution:** Verify the field value matches the placeholder value
  exactly. Use `:on_placeholder_conflict` to force replacement.

  See also `EctoShorts.Actions`, `EctoShorts.CommonSchema`, and
  `c:Ecto.Repo.insert_all/3`.
  """

  alias Ecto.Changeset
  alias EctoShorts.CommonParams.Placeholders
  alias EctoShorts.CommonParams.Timestamps
  alias EctoShorts.CommonSchema
  alias EctoShorts.CommonFilters.UpdateExpr
  alias EctoShorts.Utils

  @doc """
  Builds conflict resolution options for use with `c:Ecto.Repo.insert_all/3`.

  `source` is a schema module or `{source, schema}` tuple. `inserts` is the
  list of prepared insert maps (output of `convert_to_insert_params/3`).
  `opts` is a keyword list of options.

  When the schema has a primary key and at least one insert contains all
  non-nil primary key values, returns a keyword list with `:conflict_target`
  set to the primary key fields. If there are non-primary-key fields to
  replace, also includes `on_conflict: {:replace, fields}`.

  Returns an empty list when no conflict handling applies (e.g. when the
  schema has no primary key, or all primary key values are `nil`).

  ## Options

  * `:on_conflict_replace` - controls which fields are replaced on conflict.
    Defaults to `:insert_keys`.
    * `:insert_keys` - replaces all non-primary-key fields present in the inserts.
    * `:none` - no fields are replaced on conflict (insert-or-do-nothing). The returned
      list contains `conflict_target:` and `on_conflict: :nothing`.
    * a list of atoms - only the listed fields are replaced.

  ## Examples

      iex> inserts = [%{id: 1, title: "Hello", published: true}]
      iex> opts = EctoShorts.CommonParams.build_on_conflict_options(
      ...>   EctoShorts.Schema.Post, inserts, []
      ...> )
      iex> Keyword.has_key?(opts, :conflict_target)
      true

      iex> inserts = [%{id: 1, title: "Hello"}]
      iex> opts = EctoShorts.CommonParams.build_on_conflict_options(
      ...>   EctoShorts.Schema.Post, inserts, on_conflict_replace: :none
      ...> )
      iex> {opts[:conflict_target], opts[:on_conflict]}
      {[:id], :nothing}

      iex> EctoShorts.CommonParams.build_on_conflict_options(EctoShorts.Schema.Post, [], [])
      []

  See also `convert_to_insert_params/3` and `c:Ecto.Repo.insert_all/3`.
  """
  @spec build_on_conflict_options(
          source :: module() | {binary(), module()},
          inserts :: [map()],
          opts :: keyword()
        ) :: keyword()
  def build_on_conflict_options(source, inserts, opts) when is_list(inserts) do
    with schema when not is_nil(schema) <- normalize_schema(source),
         true <- inserts !== [],
         true <- Enum.any?(inserts, &has_all_non_nil_primary_keys?(schema, &1)) do
      build_conflict_options(schema, inserts, opts)
    else
      _ -> []
    end
  end

  defp build_conflict_options(schema, inserts, opts) do
    conflict_target = schema.__schema__(:primary_key)
    replace_fields = get_replace_fields(inserts, conflict_target, opts)

    if replace_fields === [] do
      [conflict_target: conflict_target, on_conflict: :nothing]
    else
      [conflict_target: conflict_target, on_conflict: {:replace, replace_fields}]
    end
  end

  defp get_replace_fields(inserts, conflict_target, opts) do
    case Keyword.get(opts, :on_conflict_replace, :insert_keys) do
      :none ->
        []

      :insert_keys ->
        inserts
        |> Enum.flat_map(&Map.keys/1)
        |> Enum.uniq()
        |> Enum.reject(&(&1 in conflict_target))
        |> Enum.sort()

      fields when is_list(fields) ->
        fields
        |> Enum.uniq()
        |> Enum.reject(&(&1 in conflict_target))
        |> Enum.sort()

      invalid_term ->
        raise ArgumentError,
              "Expected :on_conflict_replace to be :none, :insert_keys, or a list of fields, " <>
                "got: #{inspect(invalid_term)}"
    end
  end

  @doc """
  Converts a list of parameters or structs into the format expected by
  `c:Ecto.Repo.insert_all/3`, with support for validation, timestamps, and
  placeholder substitution.

  `source` is a schema module or `{source, schema}` tuple (or `nil` for
  schemaless inserts). `params_list` is a list of maps, keyword lists,
  schema structs, changesets, or `{struct, params}` tuples.

  Returns `{:ok, [map()]}` on success, or `{:error, [changeset]}` when
  one or more entries fail validation.

  ## Options

  ### Placeholder options

  * `:placeholders` - a map where each key is a field atom and each value is
    the placeholder value to match. When a field value matches, it is replaced
    with `{:placeholder, field_name}` for use with `c:Ecto.Repo.insert_all/3`'s
    `:placeholders` option. Defaults to `%{}`.
  * `:on_placeholder_conflict` - controls what happens when a placeholder value
    is provided but the record already has a different value. Defaults to
    `:nothing`.
    * `:nothing` - keep the existing value unchanged.
    * `:replace_all` - always use the placeholder regardless of conflict.
    * `{:replace, fields}` - only replace the listed fields.

  ### Timestamp options

  * `:inserted_at` - manually set the `:inserted_at` timestamp value.
  * `:updated_at` - manually set the `:updated_at` timestamp value.
  * `:inserted_at_source` - override the field name (e.g. `:created_on`).
  * `:updated_at_source` - override the field name.
  * `:inserted_at_timestamp_type` - override the timestamp type
    (`:naive_datetime`, `:naive_datetime_usec`, `:utc_datetime`, or `:utc_datetime_usec`).
  * `:updated_at_timestamp_type` - override the timestamp type.
  * `:timestamp_type` - fallback type for both fields when specific overrides are absent.

  ### Validation options

  * `:validate` - when `true`, each entry is passed through the schema's
    `changeset/2` for validation. Set to `false` to construct raw structs
    without calling `changeset/2`. Defaults to `true`.

  ## Examples

      iex> {:ok, inserts} =
      ...>   EctoShorts.CommonParams.convert_to_insert_params(
      ...>     EctoShorts.Schema.Post,
      ...>     [%{title: "Hello", body: "World"}]
      ...>   )
      iex> is_list(inserts)
      true

      iex> EctoShorts.CommonParams.convert_to_insert_params(EctoShorts.Schema.Post, [])
      {:ok, []}

  See also `build_on_conflict_options/3` and `convert_to_update_params/3`.
  """
  @spec convert_to_insert_params(
          source :: module() | {binary(), module()} | nil,
          params_list :: list(),
          opts :: keyword()
        ) :: {:ok, [map()]} | {:error, [Ecto.Changeset.t()]}
  def convert_to_insert_params(source, params_list \\ [], opts \\ []) do
    schema = normalize_schema(source)

    case build_inserts(params_list, schema, opts) do
      {inserts, []} ->
        {:ok, Enum.reverse(inserts)}

      {_, errors} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp build_inserts(params_list, schema, opts) do
    utc_now = DateTime.utc_now()

    Enum.reduce(
      params_list,
      {[], []},
      fn params, {acc, errors} ->
        case normalize_insert_entry(schema, params, opts) do
          {:ok, insert_data, changed_keys} ->
            insert_data =
              build_insert_map(schema, insert_data, utc_now, changed_keys, opts)

            {[insert_data | acc], errors}

          {:error, e} ->
            {acc, [e | errors]}
        end
      end
    )
  end

  defp normalize_insert_params(nil, params, _opts) do
    to_map!(params)
  end

  defp normalize_insert_params(schema, params, opts) do
    query_fields = CommonSchema.get_query_fields(opts, schema)

    params
    |> to_map!()
    |> Map.take(query_fields)
  end

  defp to_map!(params) do
    cond do
      is_map(params) ->
        Utils.atomize_keys(params)

      Keyword.keyword?(params) ->
        Map.new(params)

      true ->
        raise ArgumentError,
              "Expected params to be a map or keyword list, got: #{inspect(params)}"
    end
  end

  defp build_struct(schema, schema_struct, params, opts) do
    if opts[:validate] === false do
      {:ok, struct(schema_struct, params)}
    else
      schema_struct
      |> CommonSchema.create_changeset(params, opts)
      |> Changeset.apply_action(changeset_action(schema, schema_struct))
    end
  end

  defp build_changeset(schema, %{data: schema_struct} = changeset, opts) do
    if opts[:validate] === false do
      {:ok, Changeset.apply_changes(changeset)}
    else
      Changeset.apply_action(changeset, changeset_action(schema, schema_struct))
    end
  end

  defp build_schema_data(schema, params, opts) do
    if opts[:validate] === false do
      {:ok, struct(schema, params)}
    else
      with {:ok, insert_data} <-
             schema
             |> CommonSchema.create_changeset(params, opts)
             |> Changeset.apply_action(:insert) do
        insert_data =
          if has_all_non_nil_primary_keys?(schema, params) do
            struct!(insert_data, Map.take(params, schema.__schema__(:primary_key)))
          else
            insert_data
          end

        {:ok, insert_data}
      end
    end
  end

  defp normalize_insert_entry(schema, {%{data: schema_struct} = _changeset, params}, opts) do
    normalize_insert_entry(schema, {schema_struct, params}, opts)
  end

  defp normalize_insert_entry(nil, params, opts) do
    params = normalize_insert_params(nil, params, opts)

    if is_map(params) and not is_struct(params) do
      {:ok, params, Map.keys(params)}
    else
      {:error, {:invalid_insert_entry, params}}
    end
  end

  defp normalize_insert_entry(schema, {%_{} = schema_struct, params}, opts) do
    params = normalize_insert_params(schema, params, opts)
    changed_keys = keys_changed_in_schema_data(schema_struct, params)

    with {:ok, insert_data} <- build_struct(schema, schema_struct, params, opts) do
      {:ok, insert_data, changed_keys}
    end
  end

  defp normalize_insert_entry(schema, %Ecto.Changeset{data: schema_struct} = changeset, opts) do
    params = normalize_insert_params(schema, changeset.params, opts)
    changed_keys = keys_changed_in_schema_data(schema_struct, params)

    with {:ok, insert_data} <- build_changeset(schema, changeset, opts) do
      {:ok, insert_data, changed_keys}
    end
  end

  defp normalize_insert_entry(schema, %_{} = schema_struct, opts) do
    changed_keys = CommonSchema.get_query_fields(opts, schema)

    with {:ok, insert_data} <- build_struct(schema, schema_struct, %{}, opts) do
      {:ok, insert_data, changed_keys}
    end
  end

  defp normalize_insert_entry(schema, params, opts) do
    params = normalize_insert_params(schema, params, opts)
    query_fields = CommonSchema.get_query_fields(opts, schema)
    changed_keys = keys_changed_in_params(query_fields, params)

    with {:ok, insert_data} <- build_schema_data(schema, params, opts) do
      {:ok, insert_data, changed_keys}
    end
  end

  defp keys_changed_in_schema_data(schema_struct, map_b) do
    Enum.reduce(map_b, [], fn {key, val}, acc ->
      if Map.get(schema_struct, key) !== val do
        [key | acc]
      else
        acc
      end
    end)
  end

  defp keys_changed_in_params(query_fields, params) do
    Enum.reduce(query_fields, [], fn query_field, acc ->
      if Map.has_key?(params, query_field) do
        [query_field | acc]
      else
        acc
      end
    end)
  end

  defp changeset_action(schema, schema_struct) do
    if has_all_non_nil_primary_keys?(schema, schema_struct) do
      :update
    else
      :insert
    end
  end

  defp has_all_non_nil_primary_keys?(schema, schema_data_or_params) do
    primary_key = schema.__schema__(:primary_key)

    Enum.all?(primary_key, fn key ->
      Map.get(schema_data_or_params, key) !== nil
    end)
  end

  defp build_insert_map(nil, insert_data, utc_now, changed_keys, opts) do
    insert_data
    |> filter_insert_changes(changed_keys)
    |> Placeholders.put_placeholders(opts[:placeholders] || %{}, opts)
    |> Timestamps.put_timestamps(utc_now, nil, opts)
  end

  defp build_insert_map(schema, insert_data, utc_now, changed_keys, opts) do
    query_fields = CommonSchema.get_query_fields(opts, schema)

    insert_data
    |> Map.take(query_fields)
    |> filter_insert_changes(changed_keys)
    |> Placeholders.put_placeholders(opts[:placeholders] || %{}, opts)
    |> Timestamps.put_timestamps(utc_now, schema, opts)
  end

  defp filter_insert_changes(insert_data, changed_keys) do
    Enum.reduce(insert_data, %{}, fn {key, value}, acc ->
      if value !== nil or (value === nil and Enum.member?(changed_keys, key)) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  @doc """
  Converts a map of update parameters into the format expected by
  `c:Ecto.Repo.update_all/3`.

  `source` is a schema module or `{source, schema}` tuple (or `nil` for
  schemaless updates). `params` is a map of `{field, value}` pairs.

  The value for each field can be:

  * A plain value - equivalent to `{:set, value}`.
  * `{:set, value}` - explicit set.
  * `{:inc, integer}` - increment a field of type `:integer`.
  * `{:push, value}` - append to a field of type `{:array, _}`.
  * `{:pull, value}` - remove from a field of type `{:array, _}`.
  * A list of the above tagged tuples - applies each operation in sequence.

  Raises `ArgumentError` when `:inc` is used on a non-integer field, or when
  `:push`/`:pull` is used on a non-array field.

  Returns a keyword list of update operations (e.g.
  `[set: [title: "New"], inc: [views: 1]]`) ready to be passed as the
  second argument to `c:Ecto.Repo.update_all/3`. Returns an empty list when
  no valid fields are found in `params`.

  ## Options

  * `:updated_at` - manually provide the timestamp value for `:updated_at`.
  * `:updated_at_source` - override the field name. Defaults to `:updated_at`.
  * `:updated_at_timestamp_type` - override the timestamp type
    (`:naive_datetime` or `:utc_datetime`).
  * `:timestamp_type` - fallback timestamp type when the specific override
    is not provided.

  ## Examples

      iex> EctoShorts.CommonParams.convert_to_update_params(
      ...>   EctoShorts.Schema.Post,
      ...>   %{title: "Updated", views: {:inc, 1}}
      ...> )
      [inc: [views: 1], set: [title: "Updated", updated_at: ...]]

      iex> EctoShorts.CommonParams.convert_to_update_params(EctoShorts.Schema.Post, %{})
      []

  See also `convert_to_insert_params/3` and `build_on_conflict_options/3`.
  """
  @spec convert_to_update_params(
          source :: module() | {binary(), module()} | nil,
          params :: map(),
          opts :: keyword()
        ) :: keyword()
  def convert_to_update_params(source, params, opts \\ []) do
    utc_now = DateTime.utc_now()

    schema = normalize_schema(source)

    with updates when updates !== [] <-
           schema
           |> UpdateExpr.build_update_operations(params, opts)
           |> group_update_operations() do
      updates
      |> Timestamps.put_set_updated_at(utc_now, schema, opts)
      |> Enum.map(fn {key, values} -> {key, Enum.sort(values)} end)
      |> Enum.sort()
    end
  end

  defp group_update_operations(update_operations) do
    update_operations
    |> Enum.group_by(fn {op, _key, _value} -> op end)
    |> Enum.map(fn {op, updates} ->
      {op, Enum.map(updates, fn {_, key, value} -> {key, value} end)}
    end)
  end

  # Helpers

  defp normalize_schema({_source, nil}), do: nil
  defp normalize_schema({_source, schema}) when is_atom(schema), do: schema
  defp normalize_schema(schema) when is_atom(schema) and schema !== nil, do: schema
  defp normalize_schema(_), do: nil
end
