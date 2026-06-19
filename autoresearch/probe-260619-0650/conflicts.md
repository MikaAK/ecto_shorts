# Probe Conflicts — Tensions the Spec Must Resolve

This file lists the rough edges between the agreed rules. None of them block the
work, but the specification must make each one clear or the rework will drift off
course.

## Words used here

- Ecto: the Elixir library for talking to a database.
- Query building: turning a caller's filter parameters into a database request.
- Normalization / normalization pass: a separate step that rewrites all the
  input into one standard shape before building the query. The team wants to
  avoid this.
- Transform-at-leaf: tidy each filter piece at the moment it is handled, instead
  of rewriting everything up front.
- Reduce / fold: go through the items one by one, building up the result.
- Canonical term / grammar: the standard tidied form of a filter, and the full
  list of allowed shapes for it.
- Expr modules: the small helper modules that build the final query conditions.
- Warn+nil: log a warning and skip that filter, leaving the query unchanged.
- Public contract: the promises the code makes to outside callers.
- Spec: the specification document — the agreed description of how things should
  behave.

---

## T1 — Touch the whole pipeline vs. no public-interface breaks and same behavior
- **Tension:** F1 (change everything) pulls against E1 (keep the same behavior)
  and E2 (do not break the public interface).
- **Resolution (agreed):** Internal-only breaks are allowed (E2). The spec
  defines what "same behavior" means; "whole pipeline" means an *internal*
  restructure with a *stable* public surface. Workable, not a real conflict.

## T2 — "Keep exact behavior (warn+nil)" vs. "tests may be wrong" — match WHAT?
- **Tension:** E1 says keep the current behavior; G1/G4 say the current behavior
  (as written into the tests) may be wrong. So it is unclear what to match
  against: the current code? the current tests? the spec?
- **Resolution direction:** **The SPEC is the single source of truth.** Where the
  spec decides the current behavior is correct, keep it exactly (including
  warn+nil for unsupported combinations). Where the spec decides it is wrong, the
  spec wins over both the code and the tests, and the difference is written down
  as a decision.
- **Action:** The spec must include a "behavior decisions" section that, for each
  disputed behavior, states: current behavior → keep or change → why.
- **Status:** OPEN — must be made explicit in the spec.

## T3 — "No normalization pass" vs. "closed canonical-term grammar"
- **Tension:** A canonical grammar (G2) means *something* produces the standard
  tidied terms — isn't that normalization (A1)?
- **Resolution direction:** The objection (A1) is to a **separate pass that
  rewrites the whole parameter tree**. Transform-at-leaf (A2) still produces
  canonical terms, but makes them **inline inside the single reduce**, one entry
  at a time, at the moment of dispatch — not as a distinct earlier pass that
  builds a rewritten tree.
- **Action:** The spec must draw this line precisely: "tidying into the standard
  form happens at the leaf, inside the fold; no intermediate normalized structure
  is built." This distinction is the heart of the rework — get it exact.
- **Status:** OPEN — definitional line to lock down in the spec.
