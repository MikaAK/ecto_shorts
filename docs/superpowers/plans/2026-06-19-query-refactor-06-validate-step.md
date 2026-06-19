# Validate Step (HTTP Entry) — Implementation Plan (Plan 06 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the gatekeeper for untrusted (HTTP) filter params: check fields, operators, values, subquery sources, and structural limits, **returning errors as data** (never raising) so a web layer renders a 4xx — and only then hand validated params to `convert_params_to_filter`.

**Architecture:** A new module `EctoShorts.CommonFilters.Validator` with `validate(source, params, opts) :: {:ok, params} | {:error, [%ValidationError{}]}`. It collects *all* errors (doesn't stop at the first), reusing `CommonSchema` for field types and `PredicateBuilder`'s closed operator/safe-list. It is pure (no DB writes; schema reflection only). It does **not** build a query — on `{:ok, _}` the caller calls `convert_params_to_filter`. This settles the items §8 parked: the error-data shape, the `:source_aliases` registry, and the limit defaults.

**Tech Stack:** Elixir, Ecto. Tests: `ExUnit` (async), pure assertions over the returned `{:ok, _}` / `{:error, errors}`.

## Global Constraints

- Builds on Plans 01–05 (the core pipeline + `PredicateBuilder` + adapter are merged).
- **Never raise from the validate step** — it is exactly the path that keeps untrusted input off `D-RAISE`'s raising paths (§3.9). It returns errors as data.
- **Never use `alias Module, as: X`** (project convention).
- **Atoms are first-class, strings are the HTTP accommodation** (D-ELIXIR-FIRST): validation accepts string field/operator keys and resolves them through the schema / closed safe list — never `String.to_atom` on input.
- The error shape is a struct (transparency, like `Predicate`): `%EctoShorts.CommonFilters.ValidationError{path, reason}`.
- Limits are configurable with defaults; defaults chosen here.

---

### Task 1: `Validator` + `ValidationError` struct + field allow-list

**Files:**
- Create: `lib/ecto_shorts/common_filters/validation_error.ex`
- Create: `lib/ecto_shorts/common_filters/validator.ex`
- Test: `test/ecto_shorts/common_filters/validator_test.exs`

**Interfaces:**
- `%EctoShorts.CommonFilters.ValidationError{path: [term()], reason: String.t()}`.
- `Validator.validate(source, params, opts) :: {:ok, params} | {:error, [%ValidationError{}]}`. This task: walk the predicate params (`:where`/`:or_where`/bare field keys) and collect a `ValidationError` for any **field** not allowed. Allowed fields come from the schema's field list, or `opts[:allowed_keys]` for a schemaless source. Returns the params unchanged on success.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EctoShorts.CommonFilters.ValidatorTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonFilters.Validator
  alias EctoShorts.CommonFilters.ValidationError
  alias EctoShorts.Schema.Post

  test "ok when all fields exist on the schema" do
    assert {:ok, %{"age" => _}} = Validator.validate(Post, %{"views" => 10}, [])
  end

  test "error (as data, no raise) for an unknown field" do
    assert {:error, [%ValidationError{path: ["nope"], reason: reason}]} =
             Validator.validate(Post, %{"nope" => 1}, [])

    assert reason =~ "field"
  end

  test "collects ALL errors, not just the first" do
    assert {:error, errors} = Validator.validate(Post, %{"nope" => 1, "alsobad" => 2}, [])
    assert length(errors) == 2
  end
end
```

> Use `Post`'s real fields (`views`, `title`, `published`, `tags`, `inserted_at`, …). `"views"` is valid; `"nope"`/`"alsobad"` are not.

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: FAIL — `Validator` undefined.

- [ ] **Step 3: Implement the struct + field check**

```elixir
defmodule EctoShorts.CommonFilters.ValidationError do
  @moduledoc "One problem found while validating untrusted filter params."
  @enforce_keys [:path, :reason]
  defstruct [:path, :reason]
  @type t :: %__MODULE__{path: [term()], reason: String.t()}
end
```

```elixir
defmodule EctoShorts.CommonFilters.Validator do
  @moduledoc """
  Gatekeeper for untrusted (HTTP) filter params. Checks fields, operators, values,
  subquery sources, and limits, returning errors as data (never raising). On
  `{:ok, params}` the caller runs `EctoShorts.CommonFilters.convert_params_to_filter/3`.
  """
  alias EctoShorts.CommonSchema
  alias EctoShorts.CommonFilters.ValidationError

  @spec validate(term(), map() | keyword(), keyword()) ::
          {:ok, map() | keyword()} | {:error, [ValidationError.t()]}
  def validate(source, params, opts) do
    case collect_errors(source, params, opts) do
      [] -> {:ok, params}
      errors -> {:error, errors}
    end
  end

  # Reduce over the predicate params, accumulating field errors.
  defp collect_errors(source, params, opts) do
    allowed = allowed_fields(source, opts)

    Enum.reduce(params, [], fn {key, _value}, acc ->
      if field_allowed?(key, allowed) do
        acc
      else
        acc ++ [%ValidationError{path: [to_string(key)], reason: "field #{inspect(key)} is not allowed"}]
      end
    end)
  end

  defp allowed_fields(source, opts) do
    case CommonSchema.get_schema(source) do
      nil -> MapSet.new(opts[:allowed_keys] || [], &to_string/1)
      _ -> MapSet.new(CommonSchema.get_schema_reflection(source, :fields) || [], &to_string/1)
    end
  end

  defp field_allowed?(key, allowed), do: MapSet.member?(allowed, to_string(key))
end
```

> This first cut only checks top-level field keys; Tasks 2–5 extend `collect_errors` to recurse into operators, values, `or`/`and` groups, and subqueries. (Structural filter words like `:order_by`/`:limit` get their own allow-list pass in Task 5; here, focus on predicate fields.)

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/validation_error.ex lib/ecto_shorts/common_filters/validator.ex test/
git commit -m "feat(validator): skeleton + ValidationError struct + field allow-list"
```

---

### Task 2: Operator safe-list check

**Files:**
- Modify: `lib/ecto_shorts/common_filters/validator.ex`
- Test: `test/ecto_shorts/common_filters/validator_test.exs`

**Interfaces:**
- Recurse into a field's value map; any operator key not in `PredicateBuilder`'s closed safe list → a `ValidationError`. Reuses the same operator set the resolver uses (expose it from `PredicateBuilder`, e.g. `PredicateBuilder.known_operator?(raw_op)`), so validation and resolution agree.

- [ ] **Step 1: Write the failing test**

```elixir
test "ok for a known operator" do
  assert {:ok, _} = Validator.validate(Post, %{"views" => %{"gt" => 10}}, [])
end

test "error for an unknown operator" do
  assert {:error, [%ValidationError{path: ["views", "bogus"], reason: reason}]} =
           Validator.validate(Post, %{"views" => %{"bogus" => 1}}, [])

  assert reason =~ "operator"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs -k operator`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add a `PredicateBuilder.known_operator?/1` (true if `canonical_op/1` resolves to a real operator, i.e. not `:__unknown__`). In the validator, when a field's value is a map, reduce over its operator keys and add an error for any unknown one (path `[field, op]`). Leave structured operand maps (`field`/`value`/`from`/`parent`) to Task 4.

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/validator.ex lib/ecto_shorts/common_filters/predicate_builder.ex test/
git commit -m "feat(validator): operator safe-list check"
```

---

### Task 3: Value cast-check (collect cast errors)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/validator.ex`
- Test: `test/ecto_shorts/common_filters/validator_test.exs`

**Interfaces:**
- For a scalar value compared against a known-typed field, attempt `Ecto.Type.cast/2` (via a check helper); an uncastable value → a `ValidationError` (path `[field, op]`, reason names the type). Castable values pass (the actual cast still happens in `PredicateBuilder` at build time). `nil` for `eq`/`ne` is always allowed; ordering-vs-nil is left to `D-RAISE` (this is a *validation* gate, but since it can't be a valid request, surface it here as an error too, so HTTP returns 4xx rather than reaching the raise).

- [ ] **Step 1: Write the failing test**

```elixir
test "error when a value can't cast to the column type" do
  assert {:error, [%ValidationError{path: ["views", "gt"], reason: reason}]} =
           Validator.validate(Post, %{"views" => %{"gt" => "not-a-number"}}, [])

  assert reason =~ "integer" or reason =~ "cast"
end

test "ok when the value casts (string -> integer)" do
  assert {:ok, _} = Validator.validate(Post, %{"views" => %{"gt" => "10"}}, [])
end

test "an ordering operator vs nil is a validation error (kept off the raise path)" do
  assert {:error, [%ValidationError{path: ["views", "gt"]}]} =
           Validator.validate(Post, %{"views" => %{"gt" => nil}}, [])
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs -k cast`
Expected: FAIL.

- [ ] **Step 3: Implement**

Look up the field type (`opts[:field_types]` → schema reflection, same precedence as the resolver). For a scalar value, attempt `Ecto.Type.cast(type, value)`; on `:error`, add a `ValidationError`. Add the ordering-operator-vs-`nil` check (the operators `:>`/`:>=`/`:<`/`:<=` with `nil` → error). Lists cast element-wise; a `nil` element inside an `in`/`nin` list → error (mirrors D-NULL's reject).

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/validator.ex test/
git commit -m "feat(validator): value cast-check + ordering-vs-nil error"
```

---

### Task 4: Subquery-source alias registry + correlated-binding check

**Files:**
- Modify: `lib/ecto_shorts/common_filters/validator.ex`
- Test: `test/ecto_shorts/common_filters/validator_test.exs`

**Interfaces:**
- A subquery operand's `from` (in `all`/`any`/`exists`) supplied as a **string** must resolve in `opts[:source_aliases]` (a `%{"alias" => SchemaModule}` map); an unregistered alias → `ValidationError`. A `from` given as a raw **module** in an HTTP request is rejected (only the Elixir path may pass a module; the validator is for untrusted input, so a module from the wire → error). A `parent` reference's binding name must be declared by an enclosing block in the same params → else error.

- [ ] **Step 1: Write the failing test**

```elixir
test "registered subquery alias is ok" do
  params = %{"id" => %{"eq" => %{"all" => %{"from" => "comments", "where" => %{"published" => true}}}}}
  assert {:ok, _} = Validator.validate(Post, params, source_aliases: %{"comments" => EctoShorts.Schema.Comment})
end

test "unregistered subquery alias is an error" do
  params = %{"id" => %{"eq" => %{"all" => %{"from" => "secrets", "where" => %{}}}}}
  assert {:error, [%ValidationError{reason: reason}]} = Validator.validate(Post, params, source_aliases: %{})
  assert reason =~ "source"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs -k subquery`
Expected: FAIL.

- [ ] **Step 3: Implement**

When a value is a subquery operand (a map with a `from` key, possibly under `all`/`any`/`exists`), validate: the `from` string is a key in `opts[:source_aliases]` (else error); recurse into `where` validating against the *aliased* source's fields. A `parent` operand records its binding name; after the walk, check each referenced binding name was declared by an ancestor block (else error). A raw-module `from` from string-keyed (HTTP) params → error.

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/validator.ex test/
git commit -m "feat(validator): subquery-source alias registry + parent-binding check"
```

---

### Task 5: Structural limits (configurable)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/validator.ex`
- Test: `test/ecto_shorts/common_filters/validator_test.exs`

**Interfaces:**
- `opts[:limits]` (a map) caps request cost, with these **defaults**: `max_list_length: 100`, `max_or_branches: 25`, `max_nesting_depth: 8`, `max_operand_depth: 5`. Exceeding any → a `ValidationError`. These bound a hostile request (D-WIRE §1.7 / the edge-case gap on unbounded operand depth).

- [ ] **Step 1: Write the failing test**

```elixir
test "a list longer than the limit is an error" do
  big = Enum.to_list(1..200)
  assert {:error, [%ValidationError{reason: reason}]} =
           Validator.validate(Post, %{"id" => %{"in" => big}}, limits: %{max_list_length: 100})
  assert reason =~ "list"
end

test "too many OR branches is an error" do
  branches = for i <- 1..50, do: %{"views" => i}
  assert {:error, _} = Validator.validate(Post, %{"or" => branches}, limits: %{max_or_branches: 25})
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs -k limit`
Expected: FAIL.

- [ ] **Step 3: Implement**

Merge `opts[:limits]` over the defaults. During the walk, track nesting depth and operand-tree depth; check list lengths and the size of `or`/`and` branch lists. Add a `ValidationError` for each breach (path points at the offending location).

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/validator.ex test/
git commit -m "feat(validator): structural limits with configurable defaults"
```

---

### Task 6: The documented HTTP entry pattern

**Files:**
- Modify: `lib/ecto_shorts/common_filters.ex` (add a convenience `from_request/3`)
- Modify: `README.md` / module docs (document the HTTP flow)
- Test: `test/ecto_shorts/common_filters/validator_test.exs` (integration) + `test/ecto_shorts/common_filters/common_filters_schemaless_test.exs`

**Interfaces:**
- `CommonFilters.from_request(source, raw_params, opts) :: {:ok, Ecto.Query.t()} | {:error, [%ValidationError{}]}` — runs `Validator.validate/3`, and on success calls `convert_params_to_filter/3` with the validated params; on failure returns the errors for the web layer to render (e.g. 422). This is the single public entry untrusted callers use; `convert_params_to_filter/3` stays the trusted Elixir entry (which may raise, per D-RAISE).

- [ ] **Step 1: Write the failing test**

```elixir
test "from_request returns a query for valid input and errors for invalid" do
  assert {:ok, %Ecto.Query{}} =
           EctoShorts.CommonFilters.from_request(Post, %{"views" => %{"gt" => "10"}}, [])

  assert {:error, [%EctoShorts.CommonFilters.ValidationError{}]} =
           EctoShorts.CommonFilters.from_request(Post, %{"nope" => 1}, [])
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/validator_test.exs -k from_request`
Expected: FAIL.

- [ ] **Step 3: Implement**

```elixir
@doc """
Validate untrusted (HTTP) filter params, then build the query. Returns
`{:ok, query}` or `{:error, [%ValidationError{}]}` (render as 4xx). For trusted
Elixir callers, use `convert_params_to_filter/3` directly.
"""
def from_request(source, raw_params, opts \\ []) do
  case EctoShorts.CommonFilters.Validator.validate(source, raw_params, opts) do
    {:ok, params} -> {:ok, convert_params_to_filter(source, params, opts)}
    {:error, _} = error -> error
  end
end
```

Document the controller pattern in the moduledoc/README:
```elixir
case CommonFilters.from_request(Post, conn.params["filter"], allowed_keys: ~w(views title), source_aliases: %{"comments" => Comment}) do
  {:ok, query} -> json(conn, Repo.all(query))
  {:error, errors} -> conn |> put_status(422) |> json(%{errors: render_errors(errors)})
end
```

- [ ] **Step 4: Run + full suite + commit**

Run: `mix test && mix credo && mix dialyzer`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters.ex README.md test/
git commit -m "feat: CommonFilters.from_request/3 — validated HTTP entry point"
```

---

### Task 7: Close out §8 (settle the parked items)

- [ ] **Step 1:** Update the spec's §8 ("things noted for later") — the three parked items are now settled by this plan: the **error-data shape** is `%ValidationError{path, reason}`; the **registry** is `opts[:source_aliases]`; the **limit defaults** are the four in Task 5. Remove the "to be decided" framing; point §1.7 at `CommonFilters.from_request/3`.
- [ ] **Step 2:** Add the v3.0.0 migration note: the HTTP-facing entry is `from_request/3` (validates → builds); `convert_params_to_filter/3` remains the trusted Elixir entry.
- [ ] **Step 3:** Commit the spec update.

---

## Self-Review (done while writing)

- **Spec coverage:** §1.7 validate step → Tasks 1–6; the §8 parked items (error shape, registry, limits) → Tasks 4/5/7; D-RAISE's "untrusted input is validated first" (§3.9) → the whole plan + Task 6's `from_request/3`.
- **Placeholders:** none. The error struct, the four limit defaults, the `:source_aliases` shape, and `from_request/3` are all concrete.
- **Type consistency:** `Validator.validate/3` returns `{:ok, params} | {:error, [%ValidationError{}]}`; `from_request/3` threads that into `convert_params_to_filter/3`. The operator check reuses `PredicateBuilder.known_operator?/1` (added here) so validation and resolution share one operator set; field/type lookups reuse `CommonSchema` exactly as `PredicateBuilder` does — no second source of truth.
- **Pure + never raises:** the validator does schema reflection only and returns errors as data — it is the guard that keeps untrusted input off the raising paths.
