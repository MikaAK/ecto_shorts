# EctoShorts Test-Quality Rubric

Version: 2026-04-07  
Baseline coverage: 87.0%

---

## 1. What counts as redundant

A test is redundant (candidate for deletion or merging) when ALL of the following hold:

1. **Same code path** — removing it does not reduce line/branch coverage.
2. **Same behavioral contract** — the remaining tests already assert the identical public
   guarantee (e.g. `==` operator produces `WHERE field = $1`).
3. **No distinct edge value** — the test does not exercise a structurally different input
   (nil vs. non-nil, list vs. scalar, named-binding vs. positional are distinct inputs).

A test that varies only the *alias spelling* of an operator (e.g. `eq` vs `==`) is
redundant for the query-structure contract but distinct for the normalization contract.
Keep one test for the canonical form; the alias test may be deleted if the normalizer has
its own unit tests covering that alias.

---

## 2. What counts as missing coverage

A behavior is unproven (gap) when:

1. A public function has a branch that no test exercises.
2. A documented error path (raised exception, `{:error, _}`, log warning) has no test.
3. An adapter-selection code path (e.g. custom `query_builder_module`, unsupported
   `dynamic_builder` adapter) has no test.
4. A schemaless-specific behavior (e.g. `:elements` routing, field_types opt inference)
   has no schemaless test.

---

## 3. Schema-backed vs. schemaless test split

The two parallel directories (`common_filters/` and `common_filters_schemaless/`) exist
because the filter pipeline has TWO distinct code paths:

- **Schema-backed**: field type is inferred from schema metadata; type-specific routing
  (array vs. scalar, enum casting) happens automatically.
- **Schemaless**: no schema metadata; routing depends on the raw value type or explicit
  wrappers like `:elements` or `field_types:` opt.

**Rule:** a test MUST appear in both directories when the filter exercises type-dependent
routing that differs between schema and schemaless paths. A test needs to appear in ONLY
ONE directory when:
- It tests structural query modifiers (`:limit`, `:offset`, `:order_by`, `:group_by`,
  `:preload`, `:select`, `:having`, CTEs, set operations, joins) that do not vary by
  schema presence — in this case one schemaless test is sufficient unless the schema
  version has schema-specific behavior.
- It tests error/fallback paths that are identical in both modes.

Schemaless-only tests that have NO schema-backed equivalent are valid when the behavior
is exclusively schemaless (e.g. `:elements` wrapper semantics, `field_types:` opt routing).

---

## 4. Decision checklist for prune loop

Before deleting a test, confirm ALL of these:

- [ ] Coverage does not drop when test is removed (run `./scripts/coverage_score.sh`)
- [ ] No unique scenario from the scenario inventory is lost
- [ ] The test is not the only proof of an error, edge-case, or adapter override path
- [ ] If removing an alias test: the normalizer unit tests already cover that alias

Before merging two tests into one, confirm:

- [ ] The merged test still exercises both original inputs/paths
- [ ] The resulting test name accurately describes both scenarios
- [ ] Coverage does not drop

---

## 5. Decision checklist for fill loop

Before adding a test, confirm ALL of these:

- [ ] No existing test already proves this behavior (check by searching test names)
- [ ] The new test covers a distinct code branch (verify by checking coverage delta)
- [ ] If adding a schema-backed test for a structural filter: also add schemaless if
  the path differs between modes (or explicitly note why it is schema-only)
- [ ] The test targets a public API; use private branches only through the public API

---

## 6. Coverage targets by module priority

| Priority | Files | Current | Target |
|----------|-------|---------|--------|
| Critical | `query_builders.ex` | 0% | 100% |
| High | `dynamic_builders.ex` | 50% | 90%+ |
| High | `utils.ex` | 66.6% | 90%+ |
| High | `common_filters/or_having.ex` | 61.5% | 90%+ |
| High | `common_filters/update_expr.ex` | 65.0% | 90%+ |
| Medium | `common_filters/offset.ex` | 66.6% | 90%+ |
| Medium | `testing.ex` | 72% | 90%+ |
| Medium | `config.ex` | 83.3% | 90%+ |
| Medium | `dynamic_builders/postgres.ex` | 75% | 90%+ |

---

## 7. High-value test types (fill-loop priority order)

1. **Error/exception paths** — `raise`, `{:error, _}`, log warning branches
2. **Adapter override paths** — custom `query_builder_module`, unsupported DB adapter in `DynamicBuilders`
3. **Schemaless-specific behaviors** — `:elements` wrapper, `field_types:` opt edge cases
4. **Structural filter edge cases** — named binding, positional binding out-of-range
5. **Operator aliases** — only if not covered by normalizer unit tests

---

## 8. Test naming convention

Test names must read as behavioral statements, not implementation descriptions:

- GOOD: `"returns the query unchanged when the module does not export build_query/6"`
- BAD: `"calls function_exported? and falls back"`

Each test name must identify: **subject + condition + expected outcome**.
