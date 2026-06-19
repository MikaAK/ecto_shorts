# Plan — Rebuilding How EctoShorts Turns Filters Into Database Queries

**Status:** Draft for review · **Date:** 2026-06-19 · **Branch:** v3.0.0

## What this document is

EctoShorts is a small library that lets you describe what rows you want from a
database by writing a plain Elixir map, instead of writing a query by hand. For
example, you write `%{age: %{gt: 21}}` and the library builds the database request
that means "rows where age is greater than 21."

This document is the agreed description of **how that translation should work** —
both the part other people's code depends on (the promises we keep to callers)
and the part inside the library (how the pieces fit together). It is the single
source of truth: if the code or a test disagrees with this document, this document
wins, and we change the code or test to match.

The goal is a rewrite that is simpler and clearer, without changing what callers
see. Everything here is grounded in a detailed survey of the current code and
tests, stored alongside this file in `./inventory/` (four files).

---

## Words used in this document

- **Ecto** — the standard Elixir library for talking to a database.
- **Query** — a database request (the thing that fetches or changes rows).
- **Schema** — an Elixir description of one database table: its columns and the
  type of each column. EctoShorts can also work "schemaless," meaning it does not
  have this description and must be told column types another way.
- **Field** — one column of a table (for example, `age` or `title`).
- **Filter** — a piece of a request that narrows down which rows you want.
- **Operator** — a comparison word, such as "equals," "greater than," or "is one
  of." In code these are short symbols like `:==`, `:>`, `:in`.
- **Operator nickname (alias)** — a friendlier spelling of an operator. Callers
  may write `:gt`; the library treats it as `:>`. `:eq`→`:==`, `:ne`→`:!=`,
  `:gt`→`:>`, `:gte`→`:>=`, `:lt`→`:<`, `:lte`→`:<=`, `:downcase`→`:lower`,
  `:upcase`→`:upper`.
- **Condition (predicate)** — a true/false test applied to a row, such as
  "age > 21."
- **Ecto dynamic** — a condition built up in code that Ecto can later drop into a
  query. When this document says a piece of code "builds a condition," it means it
  produces one of these.
- **Tidied form (canonical form)** — the single standard shape we put a filter
  into before building the query. For example, after tidying, the nickname `:gt`
  has become `:>`, the text `"21"` has become the number `21`, and a column name
  given as text has become an Elixir atom.
- **Convert a value (cast)** — change a value into the type the column expects.
  Turning the text `"5"` into the number `5` is casting.
- **Go through one by one (reduce/fold)** — walk a list of items, building up a
  result as you go. This is the plain loop pattern we want the code to use.
- **Binding** — which table a condition points at, when a query involves more than
  one table. Most conditions point at the main table; some point at a joined one.
- **Association** — a link between two tables, such as a post and its author.
- **Subquery** — a query nested inside another query.
- **Aggregate** — a function that boils many rows down to one number, like average
  or count.
- **Pure helper (pure function)** — a function that only turns its inputs into an
  output. It does not look anything up, read configuration, or change anything
  outside itself. Pure helpers are easy to understand and test because the same
  input always gives the same output.
- **Database brand (dialect)** — the specific database product. Today EctoShorts
  only supports PostgreSQL.
- **Logs a warning and skips** — when the library is given something it cannot use
  (an unknown column, an unsupported combination), it writes a warning message to
  the log and simply leaves that filter out, rather than crashing.

---

## 0. Goal, what we are NOT doing, and the rules we follow

### 0.1 Goal
Reshape the translation so that:

1. **There is no separate "tidy everything first" step.** Today the code makes
   several passes that rewrite the whole input into a tidied shape before building
   anything. We are removing that. Instead, each filter is tidied *at the moment
   it is handled*, inside one simple loop.
2. **The small SQL-building helpers become pure helpers.** Four helper modules
   (`ScalarExpr`, `ArrayExpr`, `MapExpr`, `CommonExpr`) should each do exactly one
   thing: take an already-tidied filter and produce a database condition. They
   should never rename operators, convert values, look up column names, read the
   schema, or assume a column is called `id`.
3. **One translator does all the tidying.** A single piece — which we will call
   the **resolver** — turns a caller's raw input into the tidied form: it renames
   operators, converts values, resolves column names, and decides which helper
   should handle each filter. It contains no SQL and is not tied to any database
   brand.
4. **Plain loops replace the rewrite chains** everywhere they were hiding behind
   other names.
5. **The biggest tangled function is broken up.** One function in `ScalarExpr` is
   about 370 lines and handles a dozen different cases at once; we split it into
   small, clearly named pieces.

### 0.2 What we are NOT doing
- We are **not** adding support for other databases. We make the translator
  database-agnostic so another could be added later, but only PostgreSQL ships.
- We are **not** redesigning the whole error story. The default for a filter that
  *does not apply* stays "log a warning and skip." (But see the deliberate
  changes in §0.4 — clear caller mistakes now raise.)

### 0.3 The rules we follow (from `RULES.md`)
- **Depend on promises, not on inner workings.** Each boundary below is described
  by what goes in and what comes out, not by how it happens to be coded today.
- **Write the plan before the code.** This document is that plan. No code is
  written until it is approved.
- **Show the actual values, not just descriptions.** Every translation below shows
  a real "before" and "after."

### 0.4 Deliberate breaking changes for v3.0.0
This branch (`v3.0.0`) is unreleased, so we are taking the chance to fix
behaviors that were confusing, oversized, or didn't travel over HTTP. These **do**
change what callers see; each has a row in the decisions table (§4) and a
migration note (§7). They were validated against five independent "fresh-eyes"
designs/reviews (`reviews/fresh-eyes-review.md`).

1. **The language is reorganized into a CORE tier and an ADVANCED tier — no
   capability is removed.** (D-CORE.) The core is the everyday set that maps to
   both a query string and a JSON body (§1.4, §1.5). The advanced tier keeps the
   power-user shapes — computed-field math, column-to-column and outer-query
   comparisons, and compare-against-a-subquery (`all`/`any`/`exists`) — fully
   supported. A review confirmed they are all **JSON-body-encodable** (verified,
   §1.5a / `reviews/advanced-shapes-http-review.md`); only
   the raw-`Ecto.dynamic` escape hatch is genuinely Elixir-only. The point is
   clarity about tiers, not cutting features.
2. **One operand convention unifies the whole language (D-OPERAND).** A
   comparison's right-hand side is always a literal, a column, a subquery, or an
   outer-query reference, told apart by one reserved key (§1.5a). This replaces the
   ad-hoc `:arithmetic`/`compare` wrapper and the old `:parent_as` shape, makes the
   advanced tier HTTP-encodable, and keeps one mental model:
   `%{column: %{operator: operand}}`.
3. **The param language is specified to round-trip over HTTP.** (D-WIRE.) Operator
   keys may be strings, decoded through a fixed safe list (never `String.to_atom`
   on caller input); date-math uses a map `%{count: 1, unit: "day"}` instead of a
   tuple; client-supplied subquery sources use a registered name, never a raw
   module; date/time values are ISO 8601 text. See §1.7.
4. **A bare list always means "is one of."** (D-LIST.) The `:elements` wrapper is
   removed; on a list column, asking for *overlap* uses an explicit operator
   (`%{tags: %{overlaps: [...]}}`). A bare list never changes meaning by column
   type.
5. **Clear caller mistakes raise — but untrusted input is validated first.**
   (D-RAISE.) Calling the library wrong from Elixir raises. For HTTP, the
   documented path validates request params (allowed columns/operators, casting)
   and returns errors as data, so a bad request becomes a 4xx, not a crash. §3.9.
6. **"Not equal" no longer secretly matches empty rows.** (D-NULL.) Only
   `== nil` / `!= nil` consider null rows; every other comparison uses plain SQL.
7. **One spelling per operation.** (D-ONE-WAY.) The redundant `:aggregate` wrapper
   is removed; aggregates are written one way: `%{views: %{avg: %{gt: 5}}}`.
8. **The `:lock` and `:join` provider hooks get a checked contract.** (D-PROVIDER.)
9. **A stated rule for names that look like operators.** (D-COLLISION.) A column
   named like an operator (`count`, `before`, `data`, `all`) still works; §3.4.

### 0.5 Design tenets (and the prior art behind them)
These are the principles every decision in this document traces back to. They are
recorded here so future work and documentation can see *why* the design is shaped
the way it is, not just *what* it does.

**The prior art it builds on.** Four widely-used filter systems — built by
different teams for different ecosystems — independently arrived at almost the same
filter shape. "Consensus" below is shorthand for the structure those four share;
it is not a formal standard, and they differ in surface details.

- **MongoDB** (document database): `{age: {$gt: 21}}`
- **Prisma** (TypeScript database toolkit): `{ age: { gt: 21 } }`
- **Hasura** (auto-generated GraphQL over Postgres): `{ age: { _gt: 21 } }`
- **Ash** (Elixir application framework): `%{age: %{greater_than: 21}}`

The full per-system breakdown is in `reviews/fresh-eyes-review.md`. When this
project's own blind designers (given only the problem, not our code) landed on the
same shape, that was the signal our foundation was right.

**The tenets.**
1. **The structure describes the action.** A filter is plain data — a map — that
   reads like a description of what to fetch. This is the root tenet: it is what
   lets the same value travel from an HTTP request, through the library, to the
   database without a custom mini-language.
2. **Field-keyed, operator-nested.** `%{column: %{operator: value}}`. Operators
   live one level *below* the column, never beside it — which is what lets a column
   be named `count` or `before` without colliding with an operator (no `$`/`_`
   sigil needed). (Consensus point; our D-COLLISION rule, §3.4.)
3. **The common case is bare.** A plain value means equals (`%{status: "active"}`);
   a plain list means "is one of." No ceremony for the 80% case. (Consensus.)
4. **AND is implicit, OR is explicit.** Sibling keys are ANDed; OR is a list of
   sub-filters (`%{or: [...]}`) — forced by the fact that a map cannot hold two of
   the same key. (Consensus.)
5. **A small, closed operator set, one spelling per operation.** Adding an operator
   is a deliberate decision, not an open door. (Consensus; our D-ONE-WAY.)
6. **One operand convention.** Whatever a column is compared against — a literal, another
   column, a subquery, or an outer-query column — is told apart by one reserved key
   (§1.5a). One mental model for the whole language. (Our D-OPERAND.)
7. **HTTP-native by construction.** The decoder is dumb (it does no type guessing);
   types come from the schema; nothing on the wire is an atom or a tuple; untrusted
   input is allow-listed and validated. (Our D-WIRE, §1.7.) This is the prior-art
   lesson that JSON bodies are the home for rich filters and query strings carry
   the simple subset.
8. **A minimal core, with the rest tiered behind it.** Everyday filters form a
   small wire-safe core; power-user features are a labelled advanced tier; a raw
   Ecto condition is the final escape hatch. Capability is organized, not cut.
   (Our D-CORE.)
9. **Pure leaves, one translator.** The pieces that emit SQL are pure functions;
   all the tidying (renaming, casting, resolving, routing) lives in one
   dialect-agnostic translator. (§2.) This is an internal tenet, but it is what
   keeps the library simple enough to reason about.
10. **Safe with untrusted input.** Allow-list the columns and operators a request
    may use; never turn caller strings into atoms outside a fixed safe list; always
    pass values as parameters, never interpolate. (Prior-art lesson — Ransack's
    mass-assignment history; our D-WIRE.)
11. **Predictable failure.** A filter that does not apply is warned-and-skipped; a
    clear caller mistake raises (from Elixir) or becomes a validation error (from
    HTTP). (Our D-WARN / D-RAISE.)

---

## 1. THE PROMISE TO CALLERS — `EctoShorts.CommonFilters.convert_params_to_filter/3`

This is the front door. Other people's code calls it. Its shape and almost all of
its behavior stay the same; the few deliberate changes are listed in §0.4.

### 1.1 How it is called
```elixir
convert_params_to_filter(source, params, opts \\ [])
```
- `source` — what you are querying: a schema, or a `{table_name, schema}` pair, or
  an existing query.
- `params` — your filters, as a map or a keyword list.
- `opts` — extra options (listed in §1.6).

It returns one query with all your filters applied.

### 1.2 What it accepts
| Input | Accepted forms | Notes |
|---|---|---|
| `source` | a schema · a `{table_name, schema}` pair · an existing query | Turned into a query internally. The schemaless `{table_name, schema}` form has no column types unless you pass `:field_types`. |
| `params` | a plain map · a keyword list | Keyword lists keep duplicate keys and their order. A map is turned into a keyword list internally. Unknown keys are treated as a column filter (§1.5). |
| `opts` | a keyword list | See §1.6. |

### 1.3 What it returns
A single query with every recognized filter applied. Problems are handled in
three ways (full rule in §3.9):
- **A filter that does not apply** — an unknown column, or an operator/column
  combination with no meaning — is **logged as a warning and skipped**. The rest
  of the query is unaffected.
- **A clear caller mistake from Elixir code** — using the API in a way that
  cannot be right, such as giving an association a plain value — **raises an
  error**, because it is a bug in the calling code.
- **Untrusted input from an HTTP request** should first go through the **validate
  step** (§1.7): it checks the request against the allowed columns and operators,
  casts values, and **returns errors as data** (so the web layer answers 4xx). A
  validated request never reaches the raising path.

### 1.4 The filter words, split into core and advanced (D-CORE)
The structural filter words are grouped into two tiers. Both are still supported;
the split tells callers (and the docs) which ones are the simple, HTTP-friendly
everyday set and which are power-user features.

**Core — the everyday, HTTP-friendly set:**
```
:where :or_where :and :or            (conditions and grouping)
:order_by :reverse_order             (sorting)
:limit :offset :first :last :page    (pagination)
:select :select_merge :preload :distinct   (shaping the result)
:group_by :having :or_having         (grouping / aggregate conditions)
:join :exclude                       (joins and removing a clause)
```
Plus the two binding selectors `:as` / `:at`, any **association name** (turns into
a join plus a nested filter), and any **other** key (treated as a column filter,
the same as putting it under `:where`).

**Advanced — kept, but power-user / not part of the minimal core:**
```
:subquery :union :union_all :except :except_all :intersect :intersect_all
:with_cte :recursive_ctes :windows :with_named_binding :put_query_prefix
:lock :update :with_ties
```
These are full query-builder features. They stay available for Elixir callers, but
they are documented as advanced: several cannot be expressed in an HTTP request
(§1.7), and they are not part of the "intuitive, minimal" promise.

> The full table of every filter word — accepted shapes, what it adds, and when it
> warns-and-skips — lives in `inventory/01-common-filters.md`, section 7. The
> rewrite keeps every row the same, except where §4 says otherwise.

### 1.5 The filter-value language
Inside `:where`, `:or_where`, `:having`, `:or_having`, `:and`, `:or`, and plain
column keys, a column maps to a **value test**.

**The core value tests (wire-safe — these all round-trip over HTTP, §1.7):**
```
  a plain value          %{id: 1}                    → id equals 1
  nothing (nil)          %{published_at: %{eq: nil}} → published_at has no value
  a list                 %{id: [1, 2]}               → id is one of 1, 2 (always "is one of")
  an operator + value    %{age: %{gt: 21}}           → age greater than 21
  "not" + a value test   %{age: %{not: %{eq: 5}}}    → age is not 5
  an aggregate test      %{views: %{avg: %{gt: 5}}}  → average of views greater than 5
  a text match           %{title: %{ilike: "al"}}    → title contains "al" (case-insensitive)
  a list overlap         %{tags: %{overlaps: ["a"]}} → tags shares a value with ["a"] (list cols)
  a list size            %{tags: %{count: %{gt: 3}}} → tags has more than 3 items
  a JSON test            %{data: %{has_key: "role"}} → for columns that store JSON
  a date-math test       %{at: %{gt: %{ago: %{count: 1, unit: "day"}}}} → "1 day ago", etc.
```
Operators: `eq ne gt gte lt lte in nin like ilike overlaps count has_key
has_any_key has_all_keys contains contained_by`, plus the date shorthands. Both
the nickname (`:gt`) and its string form (`"gt"`) are accepted (§1.7). Aggregates:
`avg count max min sum`.

In the core, the right-hand side of an operator is a plain value. The advanced
tests use the **same** `%{column: %{operator: ...}}` shape, but the right-hand side
is an **operand** (§1.5a) — a column, a calculation, a subquery, or an outer-query
reference. So the advanced tier is not a separate world; it is the core shape with
a richer right-hand side. All of it encodes as a JSON body (verified, §1.5a).

```
  compare to a column    %{a: %{gt: %{field: :b}}}         → a greater than column b
  computed-field math    %{score: %{gt: %{add: [%{field: :base}, %{value: 5}]}}}
                                                            → score > base + 5
  compare to a subquery  %{id: %{eq: %{all: %{from: "comments", where: ...}}}}
                                                            → id equals every value the subquery returns
  exists                 %{exists: %{from: "comments", where: %{approved: true}}}
                                                            → rows that have a matching comment
  correlated (in exists) %{exists: %{from: "comments",
                            where: %{post_id: %{eq: %{parent: %{as: "post", field: :id}}}}}}
                                                            → comment.post_id = the outer post's id
```

**The escape hatch (a convenience, not a replacement):**
You can always build a condition with Ecto and hand it in directly:
```elixir
import Ecto.Query
%{where: dynamic([p], p.score > p.base + 5)}
```
A raw `Ecto.dynamic` passed as a value is applied as-is. This is the only
genuinely Elixir-only path; the structured shapes above all travel over HTTP.

**v3.0.0 changes to this language (see §0.4):**
- **A bare list always means "is one of" (D-LIST).** `%{tags: ["a", "b"]}` means
  "tags is one of a, b" on every column. For a *list column* overlap, use the
  explicit `overlaps` operator. The `:elements` wrapper is gone.
- **Date-math is a map, not a tuple (D-WIRE).** Write `%{ago: %{count: 1, unit:
  "day"}}`, not `%{ago: {1, :day}}`. (The tuple is still accepted from Elixir for
  convenience, but the documented, HTTP-safe form is the map.)
- **Aggregates have one spelling (D-ONE-WAY).** `%{views: %{avg: %{gt: 5}}}`. The
  `%{aggregate: %{fn: :avg, ...}}` wrapper is removed.
- **One operand convention (D-OPERAND).** Arithmetic drops its `:arithmetic`/
  `compare` wrapper; column/subquery/correlated comparisons all use the operand
  forms in §1.5a. `:parent_as` becomes `%{parent: %{as:, field:}}`, valid only
  inside a subquery/`exists`.

### 1.5a The operand convention (what a comparison's right-hand side can be)
Every operator compares the column to a **right-hand side**. In the core that side
is a plain value. In general it is one of four kinds, told apart by a single
reserved key — so a client never has to guess from position what something is:

| Kind | How you write it | Means | Wire form |
|---|---|---|---|
| Literal | `5` / `"x"` / `%{value: 5}` | a value, cast by the schema | bare scalar, or `{"value": 5}` |
| Column | `%{field: :other}` | another column on the current table | `{"field": "other"}` |
| Subquery | `%{from: "alias", where: %{…}}` | a registered source + a nested filter | `{"from":"alias","where":{…}}` |
| Correlated | `%{parent: %{as: "post", field: :id}}` | an outer query's column (inside a subquery) | `{"parent":{"as":"post","field":"id"}}` |

Rules:
- A bare scalar is sugar for `%{value: ...}`. (This also resolves the one
  ambiguity flagged in prior art: to match a JSON column against a literal map,
  write `%{value: %{...}}` explicitly.)
- **Calculations** are expression trees with **ordered-list** operands, so
  `subtract`/`divide` are unambiguous and nothing is a tuple on the wire:
  `%{add: [%{field: :base}, %{value: 5}]}`, and they nest:
  `%{add: [%{mul: [%{field: :base}, %{value: 2}]}, %{value: 5}]}`. Math words:
  `add subtract multiply divide`.
- **Subquery sources** are a **registered string alias** (`"comments"`), never a
  raw schema module from a client (D-WIRE). The nested `where` is decoded against
  that source's schema.
- **Correlated `parent`** is only valid inside a subquery/`exists`. A subquery's
  `from` may declare a binding name (`%{from: "posts", as: "post", where: …}`);
  a descendant references it via `%{parent: %{as: "post", field: …}}`. The binding
  name is checked against the names declared by enclosing blocks **in the same
  request** — a client cannot invent one.

This one convention is what makes the advanced tier HTTP-encodable and keeps the
whole language to a single mental model: `%{column: %{operator: operand}}`.

### 1.6 The options it accepts
| Option | Meaning |
|---|---|
| `:field_types` | A list of `column → type`. Overrides the schema, and is required to get list/JSON behavior on schemaless sources. |
| `:allowed_keys` | When there is no schema, the list of column names (as text) the library is allowed to accept. |
| `:sorter` | Your own function to order the filters, replacing the built-in ordering. |
| `:dynamic_builder` | Use a different database-brand translator for this one call. |
| `:query_builder_module` | Use a different filter dispatcher for this one call. |
| (set in app config) | `:repo`, `:replica`, `:dynamic_builder_module`, `:query_builder_module`, `:query_provider_module`, `:error_module`, `:max_positional_bindings`. |

### 1.7 Using it from an HTTP request (D-WIRE)
The whole point of the param shape is that a web client can build it. A request
arrives as JSON (everything is text; there are no atoms or tuples) or as a query
string. The rules that make this clean:

- **Operator keys may be strings.** `{"age": {"gt": 21}}` is the same as
  `%{age: %{gt: 21}}`. Operator strings are turned into operators through a
  **fixed safe list** — the library never calls `String.to_atom` on caller input,
  so a malicious client cannot exhaust the atom table.
- **Column names are checked, not trusted.** A column name from a request is
  matched against the schema (or `:allowed_keys`); unknown names are rejected.
- **Values stay as text and are cast by the schema.** `"21"` becomes the integer
  `21`, `"true"` becomes the boolean, dates are ISO 8601 text
  (`"2026-06-19T00:00:00Z"`) cast to the column type. The decoder does no type
  guessing.
- **Date-math is a map** (`{"ago": {"count": 1, "unit": "day"}}`) — no tuples.
- **Lists** use the standard bracket form in a query string
  (`?id[]=1&id[]=2`) and plain JSON arrays in a body.
- **A subquery source from a client is a registered name, never a raw module.**
  The server keeps a small allow-list mapping names to schemas; a client cannot
  name an arbitrary module.

**What can and cannot travel over HTTP:**
- **Query string (GET):** the core value tests, plus implicit AND (repeated
  params). It **cannot** express OR-groups, the escape hatch, or any advanced
  filter word (§1.4) — those need a JSON body or Elixir.
- **JSON body (POST):** all core value tests, plus `or`/`and` groups and JSON
  column tests. Still cannot carry the escape hatch (raw Ecto conditions) or
  subquery-by-module — those are Elixir-only.

**The validate step.** For untrusted input, the recommended entry point checks the
request against the allowed columns/operators and casts values, returning either a
clean param map or a list of errors (which the web layer renders as 4xx). This is
what keeps "raise on caller mistake" (§3.9) from turning a bad request into a 500,
and it is where field/operator allow-listing and limits (max list length, max OR
branches) are enforced.

---

## 2. THE INSIDE PROMISE — the tidied form and the translator

This is the heart of the rewrite.

**An important point first.** We tidy each filter *at the moment we handle it*,
right before building its condition — not by rewriting the whole input up front.
There is never a fully-rewritten copy of your input sitting in memory. (This is the
distinction the team cares about most; it is what "no separate tidy-everything
step" means in practice.)

### 2.1 What a fully-tidied filter looks like
When a filter is ready to be turned into SQL, it is described by five things:
```
- binding:  which table the condition points at (main table, or a named/numbered one)
- field:    the column, always as an atom (never text, never missing)
- negated:  whether this is the "not" case (yes or no)
- term:     the tidied operator-and-value (see 2.2)
- routing:  which helper handles it — scalar, array (list), map (JSON), or common
```

### 2.2 The complete list of tidied filter shapes (the core)
After tidying, every operator is a real symbol (no nicknames left), every value is
converted to the column's type, and any "not" has been pulled out into the
`negated` slot. The core grammar is small — these are the only shapes a helper
sees from the core language:

```
operators (after tidying): :== :!= :> :>= :< :<=
aggregates: :avg :count :max :min :sum
date-math: :ago :from_now :add, wrapped in :date or :datetime
text-case words: :lower :upper

A tidied core filter is one of:
  {operator, value}                         a plain comparison
  {operator, nil}                           a "has a value / has no value" check
  {:in, [values]}                           is one of a list
  {:like or :ilike, text or [texts]}        text pattern match
  {operator, {:lower or :upper, value}}     compare after lowercasing/uppercasing
  {aggregate, {operator, value}}            e.g. average greater than 5
  {operator, {:date or :datetime, {date-math, [count, interval]}}}   date math
  {:overlaps, [values]}                     list column shares a value with the list
  {:count, {operator, number}}              how many items in a list column
  {:contains / :contained_by, ...}          JSON containment
  {:has_key / :has_any_key / :has_all_keys, ...}   JSON key checks
  {:ids, [..]} / {:before/:after/:since/:until, n}   id shorthands
  {:start_date/:end_date/:since_date/:until_date, time}   date shorthands
```

**The advanced tidied shapes (still produced, just labelled advanced):**
After the operand convention (§1.5a) is resolved, the right-hand side is one of a
small set of tidied operand forms:
```
  {operator, {:field, col}}                  compare to another column
  {operator, {math, [operand, operand]}}     a calculation (operands ordered; math = :+ :- :* :/)
  {operator, {:parent, {binding, col}}}      an outer query's column (only inside a subquery)
  {operator, {:all or :any, subquery}}       compare against every/any value the subquery returns
  {:exists, subquery}                        rows for which a subquery returns anything
```
These are reached from the advanced value tests in §1.5. They flow through the
same translator and helpers as the core — nothing is deleted. The §3.7
decomposition still applies to the clauses that build them; they are reorganized
and grouped by family, not removed. All of these encode as a JSON body (§1.5a).

**The escape hatch is not tidied.** A raw `Ecto.dynamic` handed in as a value
(§1.5) is applied directly; it never goes through the translator and never reaches
a helper as a tidied shape. It exists as a convenience alongside the advanced
shapes above, not as their replacement.

**What the translator guarantees before any helper sees a core filter:**
1. The operator is a real symbol — no nicknames like `:gt` or `:downcase` remain.
2. Every value has already been converted to the column's type.
3. The column is an atom; if it came in as text, it has been resolved and checked.
4. Any "not" has been pulled out into the `negated` slot, exactly once.
5. The helper to use (scalar / array / map / common) has already been chosen.
6. The shorthands (`:ids`, `:start_date`, …) have been expanded **and the column
   they imply has been filled in** (`:ids` carries `:id`, `:start_date` carries
   `:inserted_at`), so the helpers never assume a column name. (No `:elements`
   wrapper, no `:aggregate` wrapper — see §0.4.)

### 2.3 The translator (the "resolver") — one place, no SQL, no database brand
A new piece — working name `EctoShorts.QueryBuilder.TermResolver` (final name
decided in the plan) — does all the tidying. It contains no SQL and knows nothing
about any specific database. It only knows how to convert values and read the
schema.

```elixir
# The one entry point the main loop calls for each filter:
canonicalize(source, key, raw_term, opts)
  → {:ok, %{field: atom, routing: which_helper, term: tidied_term, negated: yes/no}}
  → :skip      # column or operator could not be used; a warning was already logged

# Small pure helpers it uses:
canonical_op(raw_op)            # turns a nickname OR a string into the real operator,
                                #   through a fixed safe list (never String.to_atom)
resolve_field(source, name, opts)   # turns a column name into a checked atom, or :skip
routing_family(source, field, opts) # decides scalar / array / map / common
cast(field_type, value)         # converts a value to the column's type
```

`canonical_op/1` accepts both the Elixir nickname (`:gt`) and the HTTP string
(`"gt"`) and maps them through a **closed safe list** to the real operator. It
never calls `String.to_atom` on caller input — an operator the safe list does not
know is rejected. This is what makes the language safe to feed straight from a
JSON request (§1.7).

When `canonicalize` cannot use a filter (unknown column, unsupported shape), it
logs a warning and returns `:skip`, and the main loop simply leaves that filter
out — which keeps today's "log a warning and skip" behavior.

This translator is also where operator nicknames are turned into real operators —
it sits directly above the SQL helpers, which is exactly where we decided that work
belongs.

### 2.4 The database-brand helper (the "adapter")
```elixir
build_dynamic(routing, tidied_filter) → a database condition (or nothing)
```
The PostgreSQL adapter looks at `routing` and hands the filter to the matching
**pure** helper, then applies the "not" once if needed. The adapter receives only
tidied input — it never converts values, renames operators, resolves columns, or
reads the schema.

### 2.5 Examples — what every shape looks like, end to end

Each row shows four things: the **filter in Elixir**, the **same filter as a JSON
request body** (what a web client sends), the **tidied filter** (column · negated ·
operator-and-value · helper), and **the database condition** it becomes. Examples
use a `Post` table — `views` (number), `title` (text), `published` (true/false),
`tags` (a list of text), `inserted_at`/`published_at` (timestamps) — and a
`UserData.data` column that stores JSON. `^x` marks a value filled in safely at run
time.

**Core — scalar comparisons, "has a value", lists, text, aggregates**
| Elixir | JSON body | tidied (col · neg · term · helper) | Condition |
|---|---|---|---|
| `%{id: 1}` | `{"id":1}` | `:id` · no · `{:==,1}` · scalar | id = `^1` |
| `%{views: %{gt: 10}}` | `{"views":{"gt":10}}` | `:views` · no · `{:>,10}` · scalar | views > `^10` |
| `%{published_at: %{eq: nil}}` | `{"published_at":{"eq":null}}` | `:published_at` · no · `{:==,nil}` · scalar | published_at has no value |
| `%{published_at: %{ne: nil}}` | `{"published_at":{"ne":null}}` | `:published_at` · no · `{:!=,nil}` · scalar | published_at has a value |
| `%{id: [1,2]}` | `{"id":[1,2]}` | `:id` · no · `{:in,[1,2]}` · scalar | id is one of `^[1,2]` *(bare list = "is one of", always)* |
| `%{published: %{ne: [true]}}` | `{"published":{"ne":[true]}}` | `:published` · no · `{:!=,[true]}` · scalar | published not one of `^[true]` *(nulls excluded — D-NULL)* |
| `%{title: %{ilike: "al"}}` | `{"title":{"ilike":"al"}}` | `:title` · no · `{:ilike,"%al%"}` · scalar | title contains "al", any case *(auto-`%` — D-LIKE-WRAP)* |
| `%{title: %{ilike: "al%"}}` | `{"title":{"ilike":"al%"}}` | `:title` · no · `{:ilike,"al%"}` · scalar | title starts with "al" *(your `%` kept)* |
| `%{title: %{eq: %{downcase: "AL"}}}` | `{"title":{"eq":{"downcase":"AL"}}}` | `:title` · no · `{:==,{:lower,"AL"}}` · scalar | lower(title) = "AL" |
| `%{views: %{avg: %{gt: 10}}}` | `{"views":{"avg":{"gt":10}}}` | `:views` · no · `{:avg,{:>,10}}` · scalar | avg(views) > `^10` |
| `%{at: %{gt: %{ago: %{count: 1, unit: "day"}}}}` | `{"at":{"gt":{"ago":{"count":1,"unit":"day"}}}}` | `:at` · no · `{:>,{:datetime,{:ago,[count: 1,interval: "day"]}}}` · scalar | at > the time 1 day ago *(map, not a tuple — D-WIRE)* |

**Core — list columns, JSON columns, shorthands**
| Elixir | JSON body | tidied | Condition |
|---|---|---|---|
| `%{tags: ["a","b"]}` | `{"tags":["a","b"]}` | `:tags` · no · `{:in,["a","b"]}` · scalar | tags is one of `^["a","b"]` *(membership, like any column)* |
| `%{tags: %{overlaps: ["a","b"]}}` | `{"tags":{"overlaps":["a","b"]}}` | `:tags` · no · `{:overlaps,["a","b"]}` · array | tags shares a value with `^["a","b"]` *(explicit — D-LIST)* |
| `%{tags: %{count: %{gt: 3}}}` | `{"tags":{"count":{"gt":3}}}` | `:tags` · no · `{:count,{:>,3}}` · array | tags has more than `^3` items |
| `%{data: %{contains: %{role: "admin"}}}` | `{"data":{"contains":{"role":"admin"}}}` | `:data` · no · `{:contains,{:role,"admin"}}` · map | data's JSON contains `{role: "admin"}` |
| `%{data: %{has_key: "role"}}` | `{"data":{"has_key":"role"}}` | `:data` · no · `{:has_key,"role"}` · map | data's JSON has key "role" |
| `%{ids: [1,2,3]}` | `{"ids":[1,2,3]}` | `:id` · no · `{:ids,[1,2,3]}` · common | id is one of `^[1,2,3]` |
| `%{before: 100}` | `{"before":100}` | `:id` · no · `{:before,100}` · common | id < `^100` |
| `%{start_date: "2026-06-19T00:00:00Z"}` | `{"start_date":"2026-06-19T00:00:00Z"}` | `:inserted_at` · no · `{:start_date,t}` · common | inserted_at ≥ `^t` *(ISO 8601 text — D-WIRE)* |

**Advanced — the operand convention (§1.5a); all encode as JSON**
| Elixir | JSON body | tidied | Condition |
|---|---|---|---|
| `%{a: %{gt: %{field: :b}}}` | `{"a":{"gt":{"field":"b"}}}` | `:a` · no · `{:>,{:field,:b}}` · scalar | a > column b |
| `%{score: %{gt: %{add: [%{field: :base}, %{value: 5}]}}}` | `{"score":{"gt":{"add":[{"field":"base"},{"value":5}]}}}` | `:score` · no · `{:>,{:+,[{:field,:base},{:value,5}]}}` · scalar | score > (base + `^5`) |
| `%{id: %{eq: %{all: %{from: "comments", where: %{published: true}}}}}` | `{"id":{"eq":{"all":{"from":"comments","where":{"published":true}}}}}` | `:id` · no · `{:==,{:all,«subq»}}` · scalar | id = every value the subquery returns |
| `%{exists: %{from: "comments", where: %{approved: true}}}` | `{"exists":{"from":"comments","where":{"approved":true}}}` | — · no · `{:exists,«subq»}` · common | rows that have a matching comment |
| `%{exists: %{from: "comments", as: "c", where: %{post_id: %{eq: %{parent: %{as: "post", field: :id}}}}}}` | *(same, nested)* | … `{:==,{:parent,{:post,:id}}}` … | comment.post_id = the outer post's id *(correlated)* |

**The "not" case — wraps any shape above (the `negated` slot)**
| Elixir | JSON body | tidied | Condition |
|---|---|---|---|
| `%{views: %{not: %{eq: 10}}}` | `{"views":{"not":{"eq":10}}}` | `:views` · **yes** · `{:==,10}` | not (views = `^10`) |
| `%{published_at: %{not: %{eq: nil}}}` | `{"published_at":{"not":{"eq":null}}}` | `:published_at` · **yes** · `{:==,nil}` | published_at has a value |

> **How to read these tables.** The first column is the Elixir map; the second is
> the exact JSON a web client sends (operator names become strings, dates become
> ISO text, lists become JSON arrays — no atoms or tuples on the wire). The third
> is the filter after the translator has tidied it (real operators, converted
> values, resolved column, "not" pulled out). Turning either input form into the
> tidied form is the translator's whole job.

---

## 3. HOW THE PIECES FIT TOGETHER

### 3.1 The path a filter takes (the new design)
```
convert_params_to_filter
  │  turn the source into a query
  │  put the filters in the right order  (§3.2 — now a single pass)
  ▼
one loop over the filters                          ── EctoShorts.CommonFilters
  ├─ :as / :at      → pick which table the next filters point at, then continue
  ├─ structural words (§1.4) → hand to the matching builder module   (UNCHANGED)
  ├─ an association name      → add a join and continue with the linked table
  ├─ :and / :or               → continue with the grouped filters
  └─ a column condition (:where, :or_where, a column key, :having, :or_having)
        │  for each one:
        ▼
     translator: canonicalize(...)        ── no SQL, no database brand (§2.3)
        │   gives back a tidied filter, or "skip" (after logging a warning)
        ▼
     database-brand adapter: build_dynamic(...)     (§2.4)
        ▼
     one of the pure helpers: scalar / array / map / common   (build the condition)
        │
        ▼  add the condition to the running query (joined with AND or OR)
```

### 3.2 Putting filters in order — now a single pass (cleanup item D2)
**What it does (unchanged):** reorder the filters so they run in the right order:
plain `:where` first, then most others, then `:or_where`, then the two that must
come last (`:last`, `:subquery`).
**What changes:** today this makes four separate passes over the list. We replace
that with one pass that sorts each filter into one of four buckets, then joins the
buckets. The resulting order is exactly the same as today.

### 3.3 Turning a column name into a checked column (moves into the translator)
Same behavior as today, written as one clear set of cases instead of nested checks:
| Situation | Result |
|---|---|
| already an atom | use it as-is |
| text, schema present, column exists | use the matching atom |
| text, schema present, column does not exist | skip + warn "does not exist on schema" |
| text, no schema, name is in `:allowed_keys` | use it |
| text, no schema, name not in `:allowed_keys` | skip + warn "not in :allowed_keys" |
| text, no schema, no `:allowed_keys` given | skip + warn "no schema or allowed_keys" |

### 3.4 Choosing the right helper (moves into the translator)
First look at `:field_types`, otherwise read the schema. A list column → the array
helper; a JSON/map column → the map helper; a shorthand word → the common helper;
everything else → the scalar helper. An unknown column → skip and warn.

Because the `:elements` wrapper is gone (§0.4), the array helper is chosen **only**
when the column's type is known to be a list. On a schemaless source with no
`:field_types` entry for the column, a list value is treated as a plain
"is one of" test, not as a list-overlap test.

**Names that look like operators (D-COLLISION).** A column may legitimately be
named `count`, `before`, `data`, or `all`. The rule that removes the ambiguity:
- A **top-level** key is a column (or association, or structural word) — never an
  operator. So `%{count: 5}` filters a column named `count`.
- A key is read as an **operator only in its operator position** — that is, inside
  a value map, as in `%{tags: %{count: %{gt: 3}}}`. The first `count` (top level)
  is a column; the second (inside the value map) is the operator.
- An operator word is recognized only if it is in the operator allow-list; anything
  else inside a value map is treated as nested data (e.g. a JSON key) or rejected.
This keeps the everyday case (`%{column: value}`) unambiguous and makes operators
predictable.

### 3.5 Converting values, kept separate from renaming operators (cleanup item D5)
Today one function both converts values **and** renames operators, which mixes two
jobs. We split them:
- one helper renames operators (nicknames → real operators),
- one helper converts values to the column's type, reaching into lists and into the
  value parts of a filter, but it never touches operators.
What actually gets converted (list items, the count in a "how many" check, enum
values, and so on) stays exactly the same as today.

### 3.6 Making the helpers pure (the main cleanup) — what gets removed
| Helper | What it does wrong today | After |
|---|---|---|
| `CommonExpr` | assumes the columns are called `id` and `inserted_at` | the translator fills in the real column and passes it in |
| `ScalarExpr` | digs the column name and the count/interval out of its input itself | the translator pulls those out first; `ScalarExpr` just reads them from a fixed spot |
| `ArrayExpr`, `MapExpr` | nothing wrong | unchanged |

After the rewrite, the four helpers contain **no** value conversion, no column-name
work, no operator renaming, no schema reading, and no hardcoded column names. We
will check this with a simple search (§5).

### 3.7 Breaking up the 370-line function (cleanup item D1)
Split the one giant comparison function in `ScalarExpr` into small, clearly named
pieces — one for plain comparisons, one for "compare against a set," one for
aggregates, one for date math, one for calculations, one for comparing to an outer
query's column, one for "has a value" checks — each chosen by matching the tidied
shapes in §2.2. Then collapse the dozens of tiny near-identical builder clauses into
one small table that, given an operator and whether it is negated, produces the
condition. The conditions produced stay exactly the same.

### 3.8 The structural filters (UNCHANGED)
All the non-column filter words (`:join`, `:order_by`, `:select`, `:with_cte`, the
set operations, the pagination words, and so on) keep their current modules and
behavior exactly, including when they warn-and-skip. The loop in §3.1 hands work to
them just as today. They are touched only so they share the one column-name helper
(§3.3). Two of their warn-and-skip cases move to raising an error (§3.9):
`:reverse_order` with no prior `:order_by`, and an out-of-range or invalid binding
position. Everything else about them is unchanged.

### 3.9 When we raise an error vs. when we warn-and-skip (decision D-RAISE)
There are two kinds of problem, and they are treated differently:

- **The filter does not apply → warn and skip.** The caller asked for something
  that just has no effect here: an unknown column, or an operator/column
  combination with no meaning (for example, an average on a list column). We log a
  warning and leave that one filter out. This is the existing behavior and most of
  the 37+ cases in `inventory/04` section 3 stay this way.
- **The caller used the API wrong → raise an error.** The input cannot be a
  correct use of the library, so failing quietly would hide a bug. We raise. The
  cases that now raise:
  - an association key given a plain value instead of a map/keyword list
    (`%{author: "x"}`);
  - a binding position that is out of range or invalid (zero, negative, or higher
    than the number of tables), whether or not it is later referenced — handled
    the same way in every spot;
  - `:reverse_order` used when there is no `:order_by` to reverse;
  - a `:lock` or `:join` provider hook that returns the wrong shape or a function
    of the wrong arity (see §3.10).

  Rule of thumb: *"this filter doesn't apply" is a warning; "you called it wrong"
  is an error.*

- **Untrusted HTTP input is validated first, so it never hits the raising path.**
  The recommended request flow (§1.7) runs params through a validate step that
  checks columns/operators and casts values, **returning errors as data**. A
  malformed request (e.g. an association given a scalar) becomes a 4xx the web
  layer renders — not a 500. Raising is reserved for Elixir code calling the
  library wrong.

### 3.10 The provider-hook contract (decision D-PROVIDER)
The `:lock` and `:join` filters can call a caller-supplied function (a "provider")
to build part of the query. Today those functions can return almost anything and
mistakes turn into vague warnings. We give them a clear, checked contract:
- the allowed return shapes are written down (a built query, or a clearly-shaped
  "use this" / "nothing" / "error" result);
- the function's arity is checked;
- a return that does not fit the contract **raises** with a precise message
  (per §3.9), instead of a vague warning.

---

## 4. DECISIONS — what we keep and what we change

**The most important rule (resolving the "what do we measure against?" question):**
correctness is measured against **this document**, not against the current code and
not against the current tests. Where a decision says *keep*, today's behavior is the
promise. Where it says *change*, this document wins and we update the code and tests
to match.

Some changes here are **deliberate breaks** for the unreleased v3.0.0 (§0.4); each
is marked **Change (breaking)** and needs a line in the v3.0.0 migration notes.

| ID | Today's behavior | Decision | Why |
|---|---|---|---|
| D-WARN | A filter that does not apply (unknown column, meaningless operator/column combo) → log a warning and skip. | **Keep** | Sensible default; the translator returning "skip" reproduces it. Some *caller-mistake* cases move to raising — see D-RAISE. |
| D-API | The filters and options callers write (§1). | **Keep, except the breaks below** | Stable apart from the deliberate v3.0.0 changes in §0.4. |
| D-INTERNAL | Today's internal function names and shapes (`build_dynamic`, `apply_expr`, `dispatch_expr`, `cast_value`, `field_name_to_atom`, …). | **Free to change** | Internal; they need not survive. |
| D1 | The 370-line comparison function and dozens of tiny builder clauses. | **Change (break up)** | §3.7. The conditions produced are identical. |
| D-CommonExpr-FIELD | The shorthand helper assumes columns `id` and `inserted_at`. | **Change (internal only)** | §3.6 — the column is filled in earlier; the condition produced is identical. |
| D-CORE | One big flat surface; advanced and everyday filters mixed together. | **Change (organize)** | §1.4/§1.5. Split into a wire-safe core tier and an advanced tier. No capability removed; the minimal everyday set becomes visible. |
| D-OPERAND | Ad-hoc shapes: `:arithmetic`/`compare` wrapper, `:parent_as`, positional operands. | **Change (breaking)** | §1.5a. One operand convention (`value`/`field`/`from`/`parent`); arithmetic as ordered arrays; `parent` only inside a subquery. Unifies the language and makes the advanced tier HTTP-encodable. |
| D-WIRE | The language assumed Elixir atoms/tuples; HTTP decoding was unspecified. | **Change (breaking)** | §1.7. Operator keys may be strings (closed safe list, never `String.to_atom`); date-math is a map not a tuple; subquery sources are registered names not modules; times are ISO 8601. |
| D-LIST | List behavior needs `:elements`; a plain list vs an `:in` list mean different things on a list column. | **Change (breaking)** | §0.4/§3.4. Remove `:elements`; a bare list always means "is one of"; list overlap uses the explicit `overlaps` operator. |
| D-RAISE | Caller mistakes are silently warned-and-skipped (scalar association, bad binding, `:reverse_order` with no order, bad provider return). | **Change (breaking)** | §3.9. From Elixir these raise (a bug). Untrusted HTTP input is validated first and returns errors as data, so a bad request is a 4xx, not a crash. |
| D-NULL | `!=` / not-in against a list also matches null rows (`is_nil OR not in`); inconsistent across forms. | **Change (breaking)** | §3.5/§3.9. Only `== nil` / `!= nil` consider nulls; everything else is plain SQL. Callers who want nulls add `%{eq: nil}` explicitly. |
| D-ONE-WAY | Two spellings for aggregates (`%{avg: …}` and `%{aggregate: %{fn: :avg, …}}`). | **Change (breaking)** | §1.5. Keep one: `%{views: %{avg: %{gt: 5}}}`. Remove the wrapper. |
| D-COLLISION | No stated rule when a column is named like an operator (`count`, `before`, `data`). | **Change (clarify)** | §3.4. Top-level keys are columns; a word is an operator only in its value-map position and only if in the allow-list. |
| D-PROVIDER | The `:lock` and `:join` provider hooks are loosely checked. | **Change (breaking)** | §3.10. Checked contract; a bad return raises with a precise message. |
| D-LIKE-WRAP | `%{like: "x"}` becomes "contains x" by adding `%` signs, but `"x%"` is left alone. | **Keep, and document** | Useful, relied-upon behavior; frozen and described in §1.5. |

**`last` subquery shape** — `%{last: 10}` wraps the query in a subquery with a
reversed order. This is correct, just non-obvious; we **document** it, no behavior
change.

**Still to confirm during the work (not blocking this plan):** any other behavior
turned up by the test review (§5) that conflicts with this document gets a new row
here before the test is changed.

---

## 5. HOW WE KNOW WE ARE DONE

Because the tests are not the source of truth (this document is), the order is:

1. **Approve this document** — first gate.
2. **Review the tests one by one** against sections 1–4. For each test:
   - agrees with this document → keep it;
   - disagrees → the test is presumed wrong; we decide what is right, add a row to
     §4 recording the decision, then fix the test. No blanket auto-changing.
   - The result is written to `docs/superpowers/specs/test-audit.md`.
3. **Simple mechanical checks** that must pass after the rewrite:
   - the four helper files contain no value-conversion, operator-renaming,
     column-name, schema-reading, or hardcoded-column code (a quick text search
     finds none);
   - the filter-ordering function makes a single pass (no four separate scans).
4. **The usual checks all pass:** the test suite (after the review), the style
   checker (`mix credo`), and the type checker (`mix dialyzer`).
5. **The code is written** by the `claude-copilot:code-implementer` helper (per
   `RULES.md`), following this approved document and the implementation plan.

---

## 6. WHICH MODULES CHANGE (only the differences)

| Module | Change |
|---|---|
| `EctoShorts.CommonFilters` | filter-ordering becomes one pass; the main loop sends column conditions through the translator, then the adapter. Caller-mistake cases raise from Elixir (D-RAISE). |
| validate step (HTTP entry, §1.7) | checks request params against allowed columns/operators, casts values, and returns errors as data so a bad request is a 4xx (D-WIRE, D-RAISE). Where field/operator allow-listing and request limits live. |
| `EctoShorts.QueryBuilder.TermResolver` *(new, no database brand)* | the translator. Holds the tidying scattered across the PostgreSQL builder today, plus: the operand convention (D-OPERAND), string-operator decoding via a closed safe list and date-math maps (D-WIRE), the null rule (D-NULL), list-routing-from-type-only (D-LIST), and the operator-vs-column rule (D-COLLISION). |
| `EctoShorts.DynamicBuilders.Postgres` | shrinks to a thin adapter: take a tidied filter, pick the helper by `routing`, apply the "not." No tidying. |
| `EctoShorts.DynamicBuilders.Postgres.ScalarExpr` | becomes pure; the giant function is broken up (§3.7); the tiny builders collapse into one table; arithmetic operands become ordered lists (D-OPERAND); the null padding on list `!=` is removed (D-NULL). |
| `…ArrayExpr`, `…MapExpr` | already pure; now receive tidied filters only. `:elements` entry path is gone (D-LIST); list overlap is the explicit `overlaps` operator. |
| `…CommonExpr` | becomes pure; the column is passed in instead of assumed. |
| the structural filter modules | share the one column-name helper. The `:lock`/`:join` provider hooks gain a checked contract (D-PROVIDER); `:reverse_order`-without-order and bad bindings raise from Elixir (D-RAISE). |

---

## 7. Migration notes for v3.0.0 (caller-visible changes)
These must be listed in the release/changelog before v3.0.0 ships:
- **`:elements` is removed; a bare list always means "is one of."** Use the
  `overlaps` operator for list-column overlap; declare list columns with
  `:field_types` on schemaless sources.
- **The `:arithmetic`/`:aggregate` wrappers and the old `:parent_as` shape are
  replaced by one operand convention** (`value`/`field`/`from`/`parent`, §1.5a).
  Arithmetic operands are ordered lists; `parent` is only valid inside a subquery.
- **Operator keys may now be strings, decoded via a closed safe list**; date-math
  is a map (`%{count:, unit:}`), not a tuple; subquery sources are registered
  names, not modules; date/time values are ISO 8601 text. (HTTP-encoding rules.)
- **Some misuse raises from Elixir** (scalar association, invalid binding,
  `:reverse_order` with no order, bad provider return). For HTTP, validate request
  params first (§1.7) so a bad request is a 4xx.
- **`!=` / not-in no longer matches null rows.** Use an explicit `%{eq: nil}` if
  you want them.
- **Aggregates have one spelling** (`%{views: %{avg: %{gt: 5}}}`).
- **`:lock` / `:join` providers must follow the checked return contract.**

## 8. Things noted for later (not part of this work)
- Whether to extend "raise on misuse" any further than the cases in §3.9.
- The exact shape of the validate step's error data (field/operator/reason) — a
  small design task before the HTTP entry point is built.
- Filling the thin test spots listed in `inventory/04`, section 4 (limit, recursive
  CTE depth, nested calculations, association links).
```
