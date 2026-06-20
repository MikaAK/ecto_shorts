# Associations and Changeset Changes

`EctoShorts.CommonChanges` provides helpers for managing Ecto associations and
common changeset mutations. You call these functions inside your schema's
`changeset/2` functions, not at the Actions layer.

For an overview of how changesets flow into writes, see
[crud-actions.md](crud-actions.md).

---

## Association management

### `put_or_cast_assoc/2,3` — choose `put_assoc` or `cast_assoc` automatically

Inspects the raw value in `changeset.params` for `key` and selects the right
Ecto association strategy:

| Params value | Strategy |
|---|---|
| List of schema structs | `put_assoc` |
| List of `%{id: id}` maps only (member update) | Loads records by id, then `put_assoc` |
| List with some persisted ids mixed with new maps | Preloads existing records, then `cast_assoc` |
| Anything else (plain maps, no ids) | `cast_assoc` |

The **member-update** case is the most important to understand: when every item
in the list is exactly `%{id: integer}` (nothing else), EctoShorts treats this
as "replace the association members with this set of records" and fetches them
from the database. This is how you update a many-to-many join without sending
full changesets for each record.

```elixir
# Plain maps → cast_assoc (creates new comments)
def changeset(post, params) do
  post
  |> Ecto.Changeset.cast(params, [:title])
  |> EctoShorts.CommonChanges.put_or_cast_assoc(:comments)
end

# Member update: %{comments: [%{id: 1}, %{id: 3}]}
# → loads comments 1 and 3 and puts them on the post (no comment changeset called)
def changeset(post, params) do
  post
  |> Ecto.Changeset.cast(params, [:title])
  |> EctoShorts.CommonChanges.put_or_cast_assoc(:comments)
end
```

You normally do **not** call `put_or_cast_assoc/3` directly. Use
`preload_change_assoc/3` (below), which adds a necessary preload step first.

### `preload_change_assoc/3` — preload then put-or-cast

This is the primary association helper for `changeset/2` functions. When the
association key is present in `changeset.params`, it queries the database to
load the current association data so that `cast_assoc` can compute a correct
diff. When the key is absent from params, it falls back to `cast_assoc`
without touching the database.

```elixir
# Basic usage — handles both new records and diffs
def changeset(post, params) do
  post
  |> Ecto.Changeset.cast(params, [:title])
  |> EctoShorts.CommonChanges.preload_change_assoc(:comments)
end

# Require the association to be present
def changeset(post, params) do
  post
  |> Ecto.Changeset.cast(params, [:title])
  |> EctoShorts.CommonChanges.preload_change_assoc(:comments, required: true)
end

# Require the association when the foreign key is also absent
def changeset(order, params) do
  order
  |> Ecto.Changeset.cast(params, [:total, :user_id])
  |> EctoShorts.CommonChanges.preload_change_assoc(:user,
    required_when_missing: :user_id
  )
end
```

Options:

- `:required` — when `true`, validates that the association is present.
- `:required_when_missing` — field atom; marks the association required when
  that field is `nil` in both changes and data.
- `:repo` — the `Ecto.Repo` to use for the preload query.

---

## Changeset mutation helpers

### `put_new_change/3` — put a default only when no pending change exists

Sets a change on `field` only when there is no pending change for it. Does not
look at the persisted data value. Accepts a literal value, a 0-arity function,
or a 1-arity function (receives the field name).

```elixir
# No existing change → default is applied
changeset = Ecto.Changeset.change(%MyApp.Post{})
changeset = EctoShorts.CommonChanges.put_new_change(changeset, :title, "Untitled")
Ecto.Changeset.get_change(changeset, :title)
# => "Untitled"

# Existing change → default is skipped
changeset = Ecto.Changeset.change(%MyApp.Post{}, title: "Already set")
changeset = EctoShorts.CommonChanges.put_new_change(changeset, :title, "Untitled")
Ecto.Changeset.get_change(changeset, :title)
# => "Already set"

# 0-arity function as value
changeset = EctoShorts.CommonChanges.put_new_change(changeset, :uuid, &Ecto.UUID.generate/0)
```

### `put_new_value/3` — put a default when the current value is nil

Like `put_new_change/3`, but checks the current value (data **or** changes via
`Ecto.Changeset.get_field/2`) rather than just pending changes.

```elixir
# Data field is nil → default is applied
changeset = Ecto.Changeset.change(%MyApp.Post{title: nil})
changeset = EctoShorts.CommonChanges.put_new_value(changeset, :title, "Untitled")
Ecto.Changeset.get_change(changeset, :title)
# => "Untitled"

# Data field already has a value → default is skipped
changeset = Ecto.Changeset.change(%MyApp.Post{title: "Hello"})
changeset = EctoShorts.CommonChanges.put_new_value(changeset, :title, "Untitled")
Ecto.Changeset.get_change(changeset, :title)
# => nil (no change was made)
```

### `apply_when/3` — conditionally apply a changeset transformation

Runs `change_func` only when `when_func` returns `true`. Both functions receive
the changeset. `change_func` must return a changeset.

```elixir
changeset =
  Ecto.Changeset.change(%MyApp.Post{title: nil})

changeset =
  EctoShorts.CommonChanges.apply_when(
    changeset,
    &EctoShorts.CommonChanges.field_nil?(&1, :title),
    &Ecto.Changeset.put_change(&1, :title, "Fallback")
  )

Ecto.Changeset.get_change(changeset, :title)
# => "Fallback"
```

### `truncate_datetime_change/3` — truncate datetime precision

Truncates `DateTime` or `NaiveDateTime` changes to `:second`, `:millisecond`,
or `:microsecond`. Non-datetime values pass through unchanged.

```elixir
dt = ~U[2024-01-01 12:00:00.123456Z]
changeset = Ecto.Changeset.change(%MyApp.Post{}, inserted_at: dt)
changeset = EctoShorts.CommonChanges.truncate_datetime_change(changeset, :inserted_at, :second)
Ecto.Changeset.get_change(changeset, :inserted_at)
# => ~U[2024-01-01 12:00:00Z]

# Multiple fields at once
changeset = EctoShorts.CommonChanges.truncate_datetime_change(
  changeset,
  [:inserted_at, :updated_at],
  :millisecond
)
```

The default precision is `:second`.

### `trim_string_change/2` — strip whitespace from string changes

Applies `String.trim/1` to each pending string change. Non-string values are
passed through unchanged.

```elixir
changeset = Ecto.Changeset.change(%MyApp.Post{}, title: "  Hello World  ")
changeset = EctoShorts.CommonChanges.trim_string_change(changeset, :title)
Ecto.Changeset.get_change(changeset, :title)
# => "Hello World"

# Multiple fields
changeset = EctoShorts.CommonChanges.trim_string_change(changeset, [:title, :body])
```

---

## Changeset inspection helpers

These return booleans and are useful inside `apply_when/3` conditions or your
own guard logic.

### `change_nil?/2` — pending change is nil?

Returns `true` when the field has no pending change (or the change is `nil`).
Checks pending changes only, not the persisted data value.

```elixir
changeset = Ecto.Changeset.change(%MyApp.Post{})
EctoShorts.CommonChanges.change_nil?(changeset, :title)
# => true

changeset = Ecto.Changeset.change(%MyApp.Post{}, title: "Hi")
EctoShorts.CommonChanges.change_nil?(changeset, :title)
# => false

# Check multiple fields — true only if ALL are nil
EctoShorts.CommonChanges.change_nil?(changeset, [:title, :body])
# => false
```

### `change_empty?/2` — pending change is empty?

Returns `true` when the pending change is `[]` or `%{}`.

```elixir
changeset = Ecto.Changeset.change(%MyApp.Post{}, comments: [])
EctoShorts.CommonChanges.change_empty?(changeset, :comments)
# => true
```

### `field_nil?/2` — current value (data or changes) is nil?

Uses `Ecto.Changeset.get_field/2` — reads changes first, falls back to data.

```elixir
changeset = Ecto.Changeset.change(%MyApp.Post{title: nil})
EctoShorts.CommonChanges.field_nil?(changeset, :title)
# => true
```

### `field_empty?/2` — current value (data or changes) is an empty list?

```elixir
changeset = Ecto.Changeset.change(%MyApp.Post{comments: []})
EctoShorts.CommonChanges.field_empty?(changeset, :comments)
# => true
```

---

## Validation helpers

### `validate_not_unset/2` — prevent an existing value from being set to nil

Adds a `"can't be blank"` error when the field is being changed from a non-nil
persisted value to `nil`. Does nothing when the field was already `nil` or has
not changed.

```elixir
changeset = Ecto.Changeset.cast(
  %MyApp.Post{title: "Old title"},
  %{title: nil},
  [:title]
)
changeset = EctoShorts.CommonChanges.validate_not_unset(changeset, :title)
changeset.errors[:title]
# => {"can't be blank", []}

# Multiple fields
changeset = EctoShorts.CommonChanges.validate_not_unset(changeset, [:title, :body])
```

---

## Putting it together — a typical changeset

```elixir
defmodule MyApp.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :string
    has_many :comments, MyApp.Comment
    timestamps()
  end

  def changeset(post, params) do
    post
    |> cast(params, [:title, :body])
    |> validate_required([:title])
    |> EctoShorts.CommonChanges.trim_string_change(:title)
    |> EctoShorts.CommonChanges.validate_not_unset(:title)
    |> EctoShorts.CommonChanges.put_new_change(:body, "No body provided")
    |> EctoShorts.CommonChanges.truncate_datetime_change(:inserted_at)
    |> EctoShorts.CommonChanges.preload_change_assoc(:comments)
  end
end
```

---

## See also

- [crud-actions.md](crud-actions.md) — `create/3`, `update/4`, and the write API
- [../reference/api-reference.md](../reference/api-reference.md) — full function reference
