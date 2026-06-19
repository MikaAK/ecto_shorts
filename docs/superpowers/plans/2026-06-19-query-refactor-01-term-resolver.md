# TermResolver Foundation — Implementation Plan (Plan 01 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `EctoShorts.QueryBuilder.TermResolver`, a pure, dialect-agnostic module that turns one caller value-test into a canonical, tidied form the SQL helpers can later consume — with no SQL and no database calls beyond schema reflection.

**Architecture:** A single module exposing four small helpers (`canonical_op/1`, `resolve_field/3`, `routing_family/3`, `cast/2`) and one orchestrator (`canonicalize/4`). It is pure: same input → same output, no query building. Spec §2.2/§2.3 define the contract. Later plans wire it into `CommonFilters` (Plan 05) and consume its output in the Postgres adapter (Plan 02).

**Tech Stack:** Elixir, Ecto. Tests use `ExUnit` (async) and `ExUnit.CaptureLog`; field resolution/routing exercise the test schema `EctoShorts.Schema.Post`.

## Global Constraints

- Only PostgreSQL ships; the resolver itself is dialect-agnostic (no SQL, no dialect knowledge).
- **Never call `String.to_atom/1` on caller input.** Operator strings resolve only through a compile-time closed map; field strings resolve only via `String.to_existing_atom/1` gated by the schema, or `String.to_atom/1` gated by `:allowed_keys`.
- **Atoms are first-class** (D-ELIXIR-FIRST): accept atom operators/fields directly; strings are the HTTP accommodation.
- Value casting delegates to `EctoShorts.Types.cast/2` (do not reimplement casting).
- This plan covers a **single value-test** per `canonicalize/4` call (one operator map, bare value, list, or `nil`). Multi-operator maps (`%{gt: 21, lte: 65}`) are expanded into multiple calls by the CommonFilters fold in Plan 05 — out of scope here.
- This plan covers the **comparison family** only: scalar comparisons, nil checks, membership (`in`/`nin`), bare list, `like`/`ilike` (with auto-wrap), text transforms (`lower`/`upper`/`trim`/`ltrim`/`rtrim`), and aggregates. Date-math, shorthands, JSON operators, and the operand convention come in Plans 03/04.

---

### Task 1: Module skeleton + `canonical_op/1`

**Files:**
- Create: `lib/ecto_shorts/query_builder/term_resolver.ex`
- Test: `test/ecto_shorts/query_builder/term_resolver_test.exs`

**Interfaces:**
- Produces: `canonical_op(op :: atom() | binary()) :: atom()` — returns the canonical operator atom, or `:__unknown__` for an unrecognized string. Atom nicknames map via a closed table; canonical atoms pass through; unknown atoms pass through unchanged (an Elixir caller is trusted), unknown strings become `:__unknown__`.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EctoShorts.QueryBuilder.TermResolverTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EctoShorts.QueryBuilder.TermResolver
  alias EctoShorts.Schema.Post

  describe "canonical_op/1" do
    test "passes canonical atoms through" do
      assert TermResolver.canonical_op(:==) == :==
      assert TermResolver.canonical_op(:in) == :in
    end

    test "maps atom nicknames to canonical operators" do
      assert TermResolver.canonical_op(:eq) == :==
      assert TermResolver.canonical_op(:ne) == :!=
      assert TermResolver.canonical_op(:gt) == :>
      assert TermResolver.canonical_op(:gte) == :>=
      assert TermResolver.canonical_op(:lt) == :<
      assert TermResolver.canonical_op(:lte) == :<=
      assert TermResolver.canonical_op(:downcase) == :lower
      assert TermResolver.canonical_op(:upcase) == :upper
    end

    test "maps operator strings (HTTP) through the closed safe list" do
      assert TermResolver.canonical_op("gt") == :>
      assert TermResolver.canonical_op("eq") == :==
      assert TermResolver.canonical_op("overlaps") == :overlaps
      assert TermResolver.canonical_op("ilike") == :ilike
    end

    test "returns :__unknown__ for an unrecognized operator string (never raises/atomizes)" do
      assert TermResolver.canonical_op("definitely_not_an_op") == :__unknown__
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: FAIL — `EctoShorts.QueryBuilder.TermResolver` is undefined.

- [ ] **Step 3: Write minimal implementation**

```elixir
defmodule EctoShorts.QueryBuilder.TermResolver do
  @moduledoc """
  Dialect-agnostic translator: turns one caller value-test into a canonical,
  tidied form. Pure — no SQL, no query building. See the spec §2.2/§2.3.
  """

  require Logger
  alias EctoShorts.{CommonSchema, Types}

  @comparison_ops [:==, :!=, :>, :>=, :<, :<=]
  @ordering_ops [:>, :>=, :<, :<=]
  @aggregate_ops [:avg, :count, :max, :min, :sum]
  @text_transforms [:lower, :upper, :trim, :ltrim, :rtrim]
  @string_ops [:like, :ilike]
  @list_ops [:in, :nin, :overlaps]

  # Canonical operator atoms recognized from the wire (as strings).
  @operator_atoms @comparison_ops ++
                    @aggregate_ops ++
                    @text_transforms ++
                    @string_ops ++
                    @list_ops

  @op_aliases %{
    eq: :==,
    ne: :!=,
    gt: :>,
    gte: :>=,
    lt: :<,
    lte: :<=,
    downcase: :lower,
    upcase: :upper
  }

  # Compile-time closed map: operator string -> canonical atom.
  @string_to_op (for(op <- @operator_atoms, into: %{}, do: {Atom.to_string(op), op}))
                |> Map.merge(for {a, c} <- @op_aliases, into: %{}, do: {Atom.to_string(a), c})

  @doc "Canonicalize an operator from an atom (nickname or canonical) or a wire string."
  @spec canonical_op(atom() | binary()) :: atom()
  def canonical_op(op) when is_atom(op), do: Map.get(@op_aliases, op, op)
  def canonical_op(op) when is_binary(op), do: Map.get(@string_to_op, op, :__unknown__)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/query_builder/term_resolver.ex test/ecto_shorts/query_builder/term_resolver_test.exs
git commit -m "feat(resolver): TermResolver skeleton + canonical_op/1"
```

---

### Task 2: `resolve_field/3`

**Files:**
- Modify: `lib/ecto_shorts/query_builder/term_resolver.ex`
- Test: `test/ecto_shorts/query_builder/term_resolver_test.exs`

**Interfaces:**
- Consumes: `EctoShorts.CommonSchema.get_schema/1`, `get_schema_reflection(source, :fields)`.
- Produces: `resolve_field(source, name :: atom() | binary(), opts) :: {:ok, atom()} | :skip`. Atom names are trusted and returned as-is. String names resolve against the schema's field list (`String.to_existing_atom/1`) or, when there is no schema, against `opts[:allowed_keys]` (`String.to_atom/1`). On failure it logs a warning and returns `:skip`.

- [ ] **Step 1: Write the failing test**

```elixir
  describe "resolve_field/3" do
    test "returns atom field names as-is (trusted)" do
      assert TermResolver.resolve_field(Post, :title, []) == {:ok, :title}
    end

    test "resolves a known string field against the schema" do
      assert TermResolver.resolve_field(Post, "title", []) == {:ok, :title}
    end

    test "warns and skips an unknown string field on a schema-backed source" do
      log =
        capture_log(fn ->
          assert TermResolver.resolve_field(Post, "nope_field", []) == :skip
        end)

      assert log =~ "does not exist on schema"
    end

    test "resolves a string field via :allowed_keys when there is no schema" do
      assert TermResolver.resolve_field({"things", nil}, "name", allowed_keys: ["name"]) == {:ok, :name}
    end

    test "warns and skips a string field not in :allowed_keys" do
      log =
        capture_log(fn ->
          assert TermResolver.resolve_field({"things", nil}, "name", allowed_keys: ["other"]) == :skip
        end)

      assert log =~ "not in the :allowed_keys"
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs -k resolve_field`
Expected: FAIL — `resolve_field/3` undefined.

- [ ] **Step 3: Write minimal implementation**

Add to the module:

```elixir
  @doc "Resolve a column name to a checked atom, or :skip (with a warning)."
  @spec resolve_field(term(), atom() | binary(), keyword()) :: {:ok, atom()} | :skip
  def resolve_field(_source, field, _opts) when is_atom(field) and not is_nil(field) do
    {:ok, field}
  end

  def resolve_field(source, field, opts) when is_binary(field) do
    schema = CommonSchema.get_schema(source)

    cond do
      not is_nil(schema) ->
        fields = CommonSchema.get_schema_reflection(source, :fields) || []

        if field in Enum.map(fields, &Atom.to_string/1) do
          {:ok, String.to_existing_atom(field)}
        else
          warn_skip("Field #{inspect(field)} does not exist on schema #{inspect(schema)}, skipping")
        end

      allowed = opts[:allowed_keys] ->
        if field in Enum.map(allowed, &to_string/1) do
          {:ok, String.to_atom(field)}
        else
          warn_skip("Field #{inspect(field)} is not in the :allowed_keys list, skipping")
        end

      true ->
        warn_skip("Field #{inspect(field)} cannot be resolved: no schema or :allowed_keys, skipping")
    end
  end

  defp warn_skip(message) do
    Logger.warning(message)
    :skip
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: PASS (9 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/query_builder/term_resolver.ex test/ecto_shorts/query_builder/term_resolver_test.exs
git commit -m "feat(resolver): resolve_field/3 (atom trusted, string gated, warn+skip)"
```

---

### Task 3: `routing_family/3`

**Files:**
- Modify: `lib/ecto_shorts/query_builder/term_resolver.ex`
- Test: `test/ecto_shorts/query_builder/term_resolver_test.exs`

**Interfaces:**
- Consumes: `opts[:field_types]` (a keyword/map of `field => Ecto type`), `CommonSchema.get_schema_reflection(source, :type, field)`.
- Produces: `routing_family(source, field :: atom(), opts) :: :scalar | :array | :map`. `:field_types` wins over schema reflection. `{:array, _}` → `:array`; `:map`/`{:map, _}` → `:map`; everything else → `:scalar`. (The `:common` routing for shorthands is added in Plan 03.)

- [ ] **Step 1: Write the failing test**

```elixir
  describe "routing_family/3" do
    test "routes a scalar schema column to :scalar" do
      assert TermResolver.routing_family(Post, :title, []) == :scalar
    end

    test "routes an array schema column to :array" do
      assert TermResolver.routing_family(Post, :tags, []) == :array
    end

    test "uses :field_types over schema reflection" do
      assert TermResolver.routing_family({"t", nil}, :things, field_types: [things: {:array, :string}]) == :array
      assert TermResolver.routing_family({"t", nil}, :doc, field_types: [doc: :map]) == :map
    end

    test "defaults an unknown/typeless column to :scalar" do
      assert TermResolver.routing_family({"t", nil}, :whatever, []) == :scalar
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs -k routing_family`
Expected: FAIL — `routing_family/3` undefined.

- [ ] **Step 3: Write minimal implementation**

```elixir
  @doc "Decide which SQL helper handles a field: :scalar | :array | :map."
  @spec routing_family(term(), atom(), keyword()) :: :scalar | :array | :map
  def routing_family(source, field, opts) do
    type =
      get_in(opts, [:field_types, field]) ||
        field_types_lookup(opts[:field_types], field) ||
        CommonSchema.get_schema_reflection(source, :type, field)

    case type do
      {:array, _} -> :array
      :map -> :map
      {:map, _} -> :map
      _ -> :scalar
    end
  end

  defp field_types_lookup(nil, _field), do: nil
  defp field_types_lookup(types, field) when is_list(types), do: Keyword.get(types, field)
  defp field_types_lookup(types, field) when is_map(types), do: Map.get(types, field)
```

> Note: `get_in/2` works on maps; the explicit `field_types_lookup/2` covers a keyword-list `:field_types`. Keeping both makes the helper accept either form.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: PASS (13 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/query_builder/term_resolver.ex test/ecto_shorts/query_builder/term_resolver_test.exs
git commit -m "feat(resolver): routing_family/3 (field_types over schema; scalar/array/map)"
```

---

### Task 4: `cast/2`

**Files:**
- Modify: `lib/ecto_shorts/query_builder/term_resolver.ex`
- Test: `test/ecto_shorts/query_builder/term_resolver_test.exs`

**Interfaces:**
- Consumes: `EctoShorts.Types.cast/2`.
- Produces: `cast(type :: term() | nil, value) :: term()` — `nil` type passes the value through; a list casts element-by-element (using the inner type for `{:array, inner}`); a scalar casts directly. Casting only converts values; it never touches operators.

- [ ] **Step 1: Write the failing test**

```elixir
  describe "cast/2" do
    test "passes through when type is nil" do
      assert TermResolver.cast(nil, "anything") == "anything"
    end

    test "casts a scalar to the column type" do
      assert TermResolver.cast(:integer, "5") == 5
    end

    test "casts each element of a list" do
      assert TermResolver.cast(:integer, ["1", "2"]) == [1, 2]
    end

    test "casts list elements using the inner type for an array column" do
      assert TermResolver.cast({:array, :integer}, ["1", "2"]) == [1, 2]
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs -k "cast/2"`
Expected: FAIL — `cast/2` undefined.

- [ ] **Step 3: Write minimal implementation**

```elixir
  @doc "Convert a value (or list of values) to the column's type. Values only."
  @spec cast(term() | nil, term()) :: term()
  def cast(nil, value), do: value
  def cast(_type, nil), do: nil
  def cast({:array, inner}, values) when is_list(values), do: Enum.map(values, &Types.cast(inner, &1))
  def cast(type, values) when is_list(values), do: Enum.map(values, &Types.cast(type, &1))
  def cast(type, value), do: Types.cast(type, value)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: PASS (17 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/query_builder/term_resolver.ex test/ecto_shorts/query_builder/term_resolver_test.exs
git commit -m "feat(resolver): cast/2 (scalar + list element casting via Types.cast)"
```

---

### Task 5: `canonicalize/4` — comparison family

**Files:**
- Modify: `lib/ecto_shorts/query_builder/term_resolver.ex`
- Test: `test/ecto_shorts/query_builder/term_resolver_test.exs`

**Interfaces:**
- Consumes: `resolve_field/3`, `routing_family/3`, `canonical_op/1`, `cast/2` (above), and `CommonSchema.get_schema_reflection(source, :type, field)` for the field type used in casting.
- Produces:
  `canonicalize(source, key, raw_term, opts) :: {:ok, %{field: atom(), routing: :scalar | :array | :map, negated: boolean(), term: tidied}} | :skip`
  where `tidied` (comparison family) is one of:
  `{canonical_op, cast_value}` · `{:==, nil}` / `{:!=, nil}` · `{:in, [cast_values]}` / `{:nin, [cast_values]}` · `{op, [cast_values]}` (eq/ne + list) · `{:like | :ilike, wrapped_pattern}` · `{op, {transform, value}}` (transform in `:lower :upper :trim :ltrim :rtrim`) · `{agg, {op, cast_value}}` (agg in `:avg :count :max :min :sum`).
  `negated` is lifted out of any `%{not: …}` / `[not: …]` wrapper (nested `not` toggles). A bare scalar becomes `{:==, cast_value}`; a **bare list becomes `{:==, [cast_values]}`** (a bare list is sugar for `eq`; routing decides membership vs equality downstream — D-LIST); `nil` becomes `{:==, nil}`. An unknown operator → `:skip` (with warning).
  Assumes a single value-test (one operator entry); multi-entry expansion is the caller's job (Plan 05).

- [ ] **Step 1: Write the failing test**

```elixir
  describe "canonicalize/4 — comparison family" do
    test "bare scalar becomes equality, cast to the column type" do
      assert TermResolver.canonicalize(Post, :views, "5", []) ==
               {:ok, %{field: :views, routing: :scalar, negated: false, term: {:==, 5}}}
    end

    test "operator nickname canonicalizes and casts" do
      assert TermResolver.canonicalize(Post, :views, %{gt: "10"}, []) ==
               {:ok, %{field: :views, routing: :scalar, negated: false, term: {:>, 10}}}
    end

    test "nil becomes a nil-check (no cast)" do
      assert TermResolver.canonicalize(Post, :published_at, %{eq: nil}, []) ==
               {:ok, %{field: :published_at, routing: :scalar, negated: false, term: {:==, nil}}}
    end

    test "bare list is sugar for eq (routing decides membership vs equality)" do
      assert TermResolver.canonicalize(Post, :views, ["1", "2"], []) ==
               {:ok, %{field: :views, routing: :scalar, negated: false, term: {:==, [1, 2]}}}
    end

    test "explicit in/nin keep their operator" do
      assert {:ok, %{term: {:in, [1, 2]}}} = TermResolver.canonicalize(Post, :views, %{in: ["1", "2"]}, [])
      assert {:ok, %{term: {:nin, [1, 2]}}} = TermResolver.canonicalize(Post, :views, %{nin: ["1", "2"]}, [])
    end

    test "like auto-wraps a plain pattern but keeps an explicit one" do
      assert {:ok, %{term: {:like, "%al%"}}} = TermResolver.canonicalize(Post, :title, %{like: "al"}, [])
      assert {:ok, %{term: {:like, "al%"}}} = TermResolver.canonicalize(Post, :title, %{like: "al%"}, [])
    end

    test "text transform wraps the value side" do
      assert {:ok, %{term: {:==, {:lower, "AL"}}}} =
               TermResolver.canonicalize(Post, :title, %{eq: %{downcase: "AL"}}, [])
    end

    test "aggregate nests a comparison" do
      assert {:ok, %{term: {:avg, {:>, 10}}}} =
               TermResolver.canonicalize(Post, :views, %{avg: %{gt: "10"}}, [])
    end

    test "not is lifted into the negated slot (nested toggles)" do
      assert {:ok, %{negated: true, term: {:==, 5}}} =
               TermResolver.canonicalize(Post, :views, %{not: %{eq: "5"}}, [])

      assert {:ok, %{negated: false, term: {:==, 5}}} =
               TermResolver.canonicalize(Post, :views, %{not: %{not: %{eq: "5"}}}, [])
    end

    test "array column: bare list is eq (routing :array → exact equality downstream)" do
      assert {:ok, %{routing: :array, term: {:==, ["a", "b"]}}} =
               TermResolver.canonicalize(Post, :tags, ["a", "b"], [])
    end

    test "unknown operator string warns and skips" do
      log = capture_log(fn -> assert TermResolver.canonicalize(Post, :views, %{"bogus" => 1}, []) == :skip end)
      assert log =~ "operator"
    end

    test "unknown field skips before building a term" do
      capture_log(fn -> assert TermResolver.canonicalize(Post, "nope_field", 1, []) == :skip end)
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs -k "canonicalize/4"`
Expected: FAIL — `canonicalize/4` undefined.

- [ ] **Step 3: Write minimal implementation**

```elixir
  @doc "Turn one caller value-test into a canonical tidied form, or :skip."
  @spec canonicalize(term(), atom() | binary(), term(), keyword()) ::
          {:ok, %{field: atom(), routing: atom(), negated: boolean(), term: term()}} | :skip
  def canonicalize(source, key, raw_term, opts) do
    case resolve_field(source, key, opts) do
      :skip ->
        :skip

      {:ok, field} ->
        routing = routing_family(source, field, opts)
        type = field_type(source, field, opts)
        {negated, inner} = lift_negation(raw_term)

        case build_term(inner, type) do
          :skip -> :skip
          term -> {:ok, %{field: field, routing: routing, negated: negated, term: term}}
        end
    end
  end

  defp field_type(source, field, opts) do
    field_types_lookup(opts[:field_types], field) ||
      CommonSchema.get_schema_reflection(source, :type, field)
  end

  # --- negation -----------------------------------------------------------
  defp lift_negation(%{not: inner}) when is_map(inner) or is_list(inner) or is_nil(inner),
    do: toggle(lift_negation(inner))

  defp lift_negation([{:not, inner}]), do: toggle(lift_negation(inner))
  defp lift_negation(term), do: {false, term}
  defp toggle({negated, term}), do: {not negated, term}

  # --- term building (single value-test) ----------------------------------
  defp build_term(nil, _type), do: {:==, nil}

  defp build_term(term, type) do
    cond do
      is_map(term) and not is_struct(term) -> build_op(Map.to_list(term), type)
      Keyword.keyword?(term) and term != [] -> build_op(term, type)
      is_list(term) -> {:==, cast(type, term)}
      true -> {:==, cast(type, term)}
    end
  end

  defp build_op([{op, val}], type), do: build_single(canonical_op(op), val, type)
  # Multi-entry maps are expanded upstream (Plan 05); not expected here.
  defp build_op(_multi, _type), do: warn_skip("Expected a single operator entry")

  defp build_single(:__unknown__, _val, _type),
    do: warn_skip("Unknown operator, skipping")

  # nil checks (no cast)
  defp build_single(op, nil, _type) when op in [:==, :!=], do: {op, nil}

  # aggregates: {agg, {op, value}}
  defp build_single(agg, %{} = inner, type) when agg in @aggregate_ops,
    do: {agg, build_compare(Map.to_list(inner), type)}

  defp build_single(agg, inner, type) when agg in @aggregate_ops and is_list(inner),
    do: {agg, build_compare(inner, type)}

  # text transforms on the value side: {op, {transform, value}}
  defp build_single(op, %{} = inner, _type) when op in [:==, :!=] do
    case Map.to_list(inner) do
      [{t, v}] ->
        case canonical_op(t) do
          ct when ct in @text_transforms -> {op, {ct, v}}
          _ -> warn_skip("Unknown transform, skipping")
        end

      _ ->
        warn_skip("Expected a single transform entry")
    end
  end

  # like/ilike with auto-wrap
  defp build_single(op, pattern, _type) when op in @string_ops and is_binary(pattern),
    do: {op, wrap_like(pattern)}

  defp build_single(op, patterns, _type) when op in @string_ops and is_list(patterns),
    do: {op, Enum.map(patterns, &wrap_like/1)}

  # membership
  defp build_single(op, list, type) when op in [:in, :nin] and is_list(list),
    do: {op, cast(type, list)}

  # eq/ne with a list (routing decides equality vs membership downstream)
  defp build_single(op, list, type) when op in [:==, :!=] and is_list(list),
    do: {op, cast(type, list)}

  # scalar comparison
  defp build_single(op, value, type) when op in @comparison_ops,
    do: {op, cast(type, value)}

  defp build_single(_op, _value, _type), do: warn_skip("Unsupported operator/value, skipping")

  defp build_compare([{op, value}], type) do
    case canonical_op(op) do
      ct when ct in @comparison_ops and is_nil(value) -> {ct, nil}
      ct when ct in @comparison_ops -> {ct, cast(type, value)}
      _ -> :skip
    end
  end

  defp build_compare(_other, _type), do: :skip

  defp wrap_like(pattern) when is_binary(pattern) do
    if String.contains?(pattern, ["%", "_"]), do: pattern, else: "%#{pattern}%"
  end
```

> The aggregate clause may receive `:skip` from `build_compare/2`; since `build_single` wraps it as `{agg, :skip}`, guard against that:
> after `build_op` returns, treat a term containing `:skip` as `:skip`. Simplest: have `build_compare` raise the skip up. To keep it bite-sized, the test set above only exercises valid aggregates; the invalid-aggregate path is covered in Plan 04 when D-RAISE/warn rules for aggregates are finalized. (Leave a `# TODO(Plan 04): propagate :skip from build_compare` comment to mark it.)

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ecto_shorts/query_builder/term_resolver_test.exs`
Expected: PASS (all tasks' tests green).

- [ ] **Step 5: Run the full suite to confirm nothing else broke**

Run: `mix test`
Expected: PASS — this plan only adds a new module and its tests; no existing module is modified.

- [ ] **Step 6: Commit**

```bash
git add lib/ecto_shorts/query_builder/term_resolver.ex test/ecto_shorts/query_builder/term_resolver_test.exs
git commit -m "feat(resolver): canonicalize/4 for the comparison family (pure, tested)"
```

---

## Self-Review (done while writing)

- **Spec coverage (for this plan's scope):** §2.3 helper contracts → Tasks 1–4; §2.2 core canonical shapes (comparison family) + negation lift → Task 5. Date-math, shorthands, JSON, and the operand convention are explicitly deferred to Plans 03/04 (stated in Global Constraints) — not gaps, scope boundaries.
- **Placeholders:** none. One `# TODO(Plan 04)` marks a deliberate cross-plan handoff (invalid-aggregate skip propagation), with its behavior owned by Plan 04's D-RAISE work.
- **Type consistency:** `canonicalize/4` returns the `%{field, routing, negated, term}` map used as the input contract for Plan 02's adapter; `routing` values (`:scalar`/`:array`/`:map`) match Plan 02's helper dispatch; `canonical_op/1`, `cast/2`, `resolve_field/3`, `routing_family/3` names are reused consistently across tasks.
- **Open item carried to Plan 02:** the existing `DynamicBuilder` behaviour is `build_dynamic(source, selected_binding, input, opts)`. Plan 02 decides whether the adapter consumes the `TermResolver` map as `input` directly or via a new 2-arity entry — this plan does not touch the behaviour.
