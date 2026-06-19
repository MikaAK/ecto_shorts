# Timestamp Schema-Field Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `EctoShorts.CommonParams.Timestamps` from adding `:inserted_at`/`:updated_at` fields that a schema-backed source does not define, which otherwise makes `Repo.insert_all/3` and `Repo.update_all/3` raise unknown-field errors.

**Architecture:** Add one shared private predicate `include_timestamp?/3` plus two per-field `explicit_*?/1` helpers to `timestamps.ex`. Gate each of the three field-adding paths (`maybe_put_inserted_at/4`, `put_timestamp_updated_at/4`, `put_set_updated_at/4`) on it. Schemaless and explicit-opt cases always add (current behavior); schema-backed default cases add only when the resolved source field is in `schema.__schema__(:fields)`.

**Tech Stack:** Elixir, Ecto, ExUnit. No DB required for these tests — the functions are pure and only introspect `__schema__/1`.

## Global Constraints

- Follow all conventions in `RULES.md` and `CLAUDE.md`.
- Code changes are delegated to the `claude-copilot:code-implementer` subagent (RULES.md), not written inline.
- No `alias Module, as: X` form (user memory: no-alias-as-option).
- `mix credo --strict` must pass (project convention; equality in normal code uses `===`).
- Tests mirror lib path: `lib/ecto_shorts/common_params/timestamps.ex` → `test/ecto_shorts/common_params/timestamps_test.exs`.

---

### Task 1: Schema-field gate + `inserted_at` insert path

**Files:**
- Create: `test/support/schema/timestamp_free.ex`
- Create: `test/ecto_shorts/common_params/timestamps_test.exs`
- Modify: `lib/ecto_shorts/common_params/timestamps.ex` (add helpers; gate `maybe_put_inserted_at/4` at lines 50-71)

**Interfaces:**
- Produces (consumed by Tasks 2 and 3):
  - `include_timestamp?(schema :: module() | nil, source_key :: atom(), explicit? :: boolean()) :: boolean()` — `true` when `schema` is `nil`, when `explicit?` is `true`, or when `source_key in schema.__schema__(:fields)`.
  - `explicit_inserted_at?(opts :: keyword()) :: boolean()` — `true` when `opts` has key `:inserted_at` or `:inserted_at_source`.
  - `explicit_updated_at?(opts :: keyword()) :: boolean()` — `true` when `opts` has key `:updated_at` or `:updated_at_source`.
- Produces: `EctoShorts.Schema.TimestampFree` — Ecto schema with fields `[:id, :title]` and **no** `timestamps()` (so `:inserted_at`/`:updated_at` are absent from `__schema__(:fields)`).

- [ ] **Step 1: Create the timestamp-free support schema**

Create `test/support/schema/timestamp_free.ex`:

```elixir
defmodule EctoShorts.Schema.TimestampFree do
  @moduledoc false
  use Ecto.Schema

  schema "timestamp_free" do
    field :title, :string
  end
end
```

This schema deliberately omits `timestamps()`, so `EctoShorts.Schema.TimestampFree.__schema__(:fields)` returns `[:id, :title]`.

- [ ] **Step 2: Write the failing tests for the inserted_at path**

Create `test/ecto_shorts/common_params/timestamps_test.exs`:

```elixir
defmodule EctoShorts.CommonParams.TimestampsTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonParams.Timestamps
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.TimestampFree

  @dt ~U[2026-01-01 00:00:00Z]

  describe "put_timestamps/4 inserted_at gating" do
    test "schema lacking :inserted_at omits it by default" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, [])

      refute Map.has_key?(result, :inserted_at)
    end

    test "schema defining :inserted_at gets it (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, Post, [])

      assert Map.has_key?(result, :inserted_at)
    end

    test "schemaless source gets :inserted_at (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, nil, [])

      assert Map.has_key?(result, :inserted_at)
    end

    test "explicit :inserted_at value forces the key onto a schema lacking it" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, inserted_at: @dt)

      assert Map.has_key?(result, :inserted_at)
    end

    test "explicit :inserted_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, inserted_at_source: :created_on)

      assert Map.has_key?(result, :created_on)
    end
  end
end
```

Note: on the insert path `opts[:inserted_at]` is not wired to the stored value (pre-existing), so the explicit-value test asserts key *presence* only, not the value.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: the "schema lacking :inserted_at omits it by default" and the explicit-source tests FAIL (key is currently always added under `:inserted_at`, never `:created_on` unless gated). The regression tests PASS.

- [ ] **Step 4: Add the shared helpers to `timestamps.ex`**

Add these private functions (place them near the other helpers, e.g. after `get_updated_at_source/1` at line 112):

```elixir
defp include_timestamp?(nil, _source_key, _explicit?), do: true
defp include_timestamp?(_schema, _source_key, true), do: true
defp include_timestamp?(schema, source_key, false), do: source_key in schema.__schema__(:fields)

defp explicit_inserted_at?(opts) do
  Keyword.has_key?(opts, :inserted_at) or Keyword.has_key?(opts, :inserted_at_source)
end

defp explicit_updated_at?(opts) do
  Keyword.has_key?(opts, :updated_at) or Keyword.has_key?(opts, :updated_at_source)
end
```

- [ ] **Step 5: Gate `maybe_put_inserted_at/4`**

Replace the function at lines 50-71:

```elixir
defp maybe_put_inserted_at(input, datetime, schema, opts) do
  source_key = inserted_at_source_key(opts)

  if source_key === false or
       not include_timestamp?(schema, source_key, explicit_inserted_at?(opts)) do
    input
  else
    result =
      if Map.has_key?(input, source_key) do
        case Map.get(input, source_key) do
          nil ->
            normalize_timestamp_inserted_at(datetime, source_key, schema, opts)

          existing_timestamp ->
            normalize_timestamp_inserted_at(existing_timestamp, source_key, schema, opts)
        end
      else
        normalize_timestamp_inserted_at(datetime, source_key, schema, opts)
      end

    Map.put(input, source_key, result)
  end
end
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: PASS (all 5 tests in the inserted_at describe block).

- [ ] **Step 7: Run credo on the changed files**

Run: `mix credo --strict lib/ecto_shorts/common_params/timestamps.ex`
Expected: no issues.

- [ ] **Step 8: Commit**

```bash
git add test/support/schema/timestamp_free.ex test/ecto_shorts/common_params/timestamps_test.exs lib/ecto_shorts/common_params/timestamps.ex
git commit -m "fix: gate inserted_at on schema field presence for schema-backed sources

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `updated_at` insert path

**Files:**
- Modify: `lib/ecto_shorts/common_params/timestamps.ex` (`put_timestamp_updated_at/4`, lines 89-104)
- Test: `test/ecto_shorts/common_params/timestamps_test.exs` (add describe block)

**Interfaces:**
- Consumes (from Task 1): `include_timestamp?/3`, `explicit_updated_at?/1`.

- [ ] **Step 1: Write the failing tests for the updated_at insert path**

Add this describe block to `test/ecto_shorts/common_params/timestamps_test.exs`:

```elixir
  describe "put_timestamps/4 updated_at gating" do
    test "schema lacking :updated_at omits it by default" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, [])

      refute Map.has_key?(result, :updated_at)
    end

    test "schema defining :updated_at gets it (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, Post, [])

      assert Map.has_key?(result, :updated_at)
    end

    test "schemaless source gets :updated_at (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, nil, [])

      assert Map.has_key?(result, :updated_at)
    end

    test "explicit :updated_at value forces the key onto a schema lacking it" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, updated_at: @dt)

      assert result[:updated_at] === @dt
    end

    test "explicit :updated_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, updated_at_source: :changed_on)

      assert Map.has_key?(result, :changed_on)
    end
  end
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: "schema lacking :updated_at omits it by default" and the explicit-source test FAIL; regression and explicit-value tests' state shows `:updated_at` always present.

- [ ] **Step 3: Gate `put_timestamp_updated_at/4`**

Replace the function at lines 89-104, adding the gate clause to the `cond`:

```elixir
defp put_timestamp_updated_at(input, datetime, schema, opts) do
  source_key = get_updated_at_source(opts)
  value = Keyword.get(opts, :updated_at)

  cond do
    source_key === false ->
      input

    value === false ->
      input

    not include_timestamp?(schema, source_key, explicit_updated_at?(opts)) ->
      input

    true ->
      value = prepare_timestamp_updated_at(value || datetime, source_key, schema, opts)
      Map.put(input, source_key, value)
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: PASS (all tests across both describe blocks).

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/common_params/timestamps.ex test/ecto_shorts/common_params/timestamps_test.exs
git commit -m "fix: gate updated_at on schema field presence for inserts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `updated_at` update (`:set`) path

**Files:**
- Modify: `lib/ecto_shorts/common_params/timestamps.ex` (`put_set_updated_at/4`, lines 27-48)
- Test: `test/ecto_shorts/common_params/timestamps_test.exs` (add describe block)

**Interfaces:**
- Consumes (from Task 1): `include_timestamp?/3`, `explicit_updated_at?/1`.

- [ ] **Step 1: Write the failing tests for the update :set path**

Add this describe block to `test/ecto_shorts/common_params/timestamps_test.exs`:

```elixir
  describe "put_set_updated_at/4 gating" do
    test "schema lacking :updated_at leaves :set untouched by default" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, [])

      refute Keyword.has_key?(result[:set], :updated_at)
    end

    test "schema defining :updated_at adds it to :set (regression)" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, Post, [])

      assert Keyword.has_key?(result[:set], :updated_at)
    end

    test "schemaless source adds :updated_at to :set (regression)" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, nil, [])

      assert Keyword.has_key?(result[:set], :updated_at)
    end

    test "explicit :updated_at value forces it onto a schema lacking the field" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, updated_at: @dt)

      assert result[:set][:updated_at] === @dt
    end

    test "explicit :updated_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, updated_at_source: :changed_on)

      assert Keyword.has_key?(result[:set], :changed_on)
    end
  end
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: "schema lacking :updated_at leaves :set untouched by default" and the explicit-source test FAIL.

- [ ] **Step 3: Gate `put_set_updated_at/4`**

Replace the function at lines 27-48, adding the gate clause to the `cond`:

```elixir
def put_set_updated_at(updates, datetime, schema, opts) do
  source_key = get_updated_at_source(opts)
  value = Keyword.get(opts, :updated_at)

  cond do
    source_key === false ->
      updates

    value === false ->
      updates

    not include_timestamp?(schema, source_key, explicit_updated_at?(opts)) ->
      updates

    true ->
      value = prepare_timestamp_updated_at(value || datetime, source_key, schema, opts)

      Keyword.update(
        updates,
        :set,
        [{source_key, value}],
        &Keyword.put(&1, source_key, value)
      )
  end
end
```

- [ ] **Step 4: Run the full file to verify all pass**

Run: `mix test test/ecto_shorts/common_params/timestamps_test.exs`
Expected: PASS (all three describe blocks).

- [ ] **Step 5: Run the broader suite + credo to confirm no regressions**

Run: `mix test test/ecto_shorts/common_params/ && mix credo --strict lib/ecto_shorts/common_params/timestamps.ex`
Expected: PASS, no credo issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ecto_shorts/common_params/timestamps.ex test/ecto_shorts/common_params/timestamps_test.exs
git commit -m "fix: gate updated_at on schema field presence for update :set

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Schemaless always-add → regression tests in Tasks 1-3. ✓
- Explicit intent forces inclusion (value + custom source) → explicit tests in each task. ✓
- Schema-backed default gated on `__schema__(:fields)` → default-omit tests in each task. ✓
- Three defect paths (inserted_at insert, updated_at insert, updated_at update) → Tasks 1, 2, 3. ✓
- New timestamp-free support schema → Task 1 Step 1. ✓
- New test file mirroring lib path → Task 1 Step 2. ✓
- Accepted consequence (typo'd explicit source silently dropped) → no warning logic added; consistent with explicit-forces-inclusion. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `include_timestamp?/3`, `explicit_inserted_at?/1`, `explicit_updated_at?/1` defined in Task 1, referenced with identical names/arities in Tasks 2-3. `EctoShorts.Schema.TimestampFree` defined Task 1, referenced consistently. ✓
