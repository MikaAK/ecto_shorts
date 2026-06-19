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
- **Operand** — the right-hand side of a comparison: the thing a column is compared
  *against*. It can be a literal value, another column, a subquery, or a reference
  to an outer query's column (§1.5a).
- **Sibling binding** — when a query joins more than one table, each joined table is
  a binding; a "sibling" binding is a *peer* in the same query (as opposed to a
  table in an enclosing/outer query). The `as:` qualifier points at one.
- **Shift** — moving a date or timestamp by an interval (e.g. 7 days later). Written
  with the `shift` word inside a `:date`/`:datetime` wrapper; kept separate from the
  arithmetic `add` so the two never collide.
- **Validate step** — the recommended entry point for *untrusted* (HTTP) input: it
  checks a request against the allowed columns and operators, casts values, and
  returns errors as data (so a bad request becomes a 4xx) instead of letting them
  reach the raising path.
- **Registered alias** — a short server-defined name (e.g. `"comments"`) that maps
  to a schema, used as a subquery source in HTTP input so a client never names a
  raw module.

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
change what callers see. This list is the caller-visible highlights; the **full**
set of decisions (including internal and framing ones) is the §4 table, and every
caller-visible change has a §7 migration note. (Decision IDs use the `D-` prefix
and are defined in §4.) They were validated against five independent "fresh-eyes"
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
12. **Elixir terms are first-class.** Even though HTTP input is supported, the
    canonical, typical form of any term is the Elixir one: if a thing can be an
    atom (an operator, a field, a binding name) or a module (a subquery source),
    that is what you normally write and what the docs show. HTTP strings are an
    accommodation decoded *into* those terms, not the primary form. (Our
    D-ELIXIR-FIRST.)

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
  JSON contains          %{data: %{contains: %{role: "admin", tier: "pro"}}}
                                                     → data contains ALL of these key/values (ANDed)
  a date-math test       %{at: %{gt: %{ago: %{count: 1, unit: "day"}}}} → "1 day ago", etc.
```
Operators: `eq ne gt gte lt lte in nin like ilike overlaps count has_key
has_any_key has_all_keys contains contained_by`, plus the date shorthands.
Text transforms (applied to the column before comparing): `lower upper trim ltrim
rtrim` (e.g. `%{title: %{eq: %{trim: "al"}}}`). Aggregates: `avg count max min
sum`. **Atoms are the first-class form** — `%{age: %{gt: 21}}` is the canonical
Elixir spelling; the string form (`"gt"`) is accepted as the HTTP accommodation
(§1.7), decoded through the same closed safe list.

There are also **shorthand words** that imply a column: `ids`, `before`, `after`,
`since`, `until` (all target the id column), and `start_date`, `end_date`,
`since_date`, `until_date` (all target `inserted_at`). And `nin` is "not in" — it
behaves exactly as a negated `in`.

**`like`/`ilike` auto-wrap (D-LIKE-WRAP).** A pattern with no `%`/`_` is wrapped as
`%pattern%` (a "contains" match): `%{title: %{like: "al"}}` matches `%al%`. If you
include your own `%`/`_`, the pattern is used as-is (`"al%"` stays "starts with").

In the core, the right-hand side of an operator is a plain value. The advanced
tests use the **same** `%{column: %{operator: ...}}` shape, but the right-hand side
is an **operand** (§1.5a) — a column, a calculation, a subquery, or an outer-query
reference. So the advanced tier is not a separate world; it is the core shape with
a richer right-hand side. All of it encodes as a JSON body (verified, §1.5a).

```
  compare to a column    %{a: %{gt: %{field: :b}}}         → a greater than column b
  sibling-binding column %{level: %{lt: %{field: :level, as: :author}}}
                                                            → level < the joined author binding's level
  computed-field math    %{score: %{gt: %{add: [%{field: :base}, %{value: 5}]}}}
                                                            → score > base + 5
  compare to a subquery  %{id: %{eq: %{all: %{from: Comment, where: ...}}}}
                                                            → id equals every value the subquery returns
  exists                 %{exists: %{from: Comment, where: %{approved: true}}}
                                                            → rows that have a matching comment
  correlated (in exists) %{exists: %{from: Comment, as: :post,
                            where: %{post_id: %{eq: %{parent: %{as: :post, field: :id}}}}}}
                                                            → comment.post_id = the outer post's id
```
(From Elixir the subquery source is the schema module `Comment`; over HTTP it is a
registered string alias `"comments"` — §1.5a, D-ELIXIR-FIRST.)

**The escape hatch (a convenience, not a replacement):**
You can always build a condition with Ecto and hand it in directly:
```elixir
import Ecto.Query
%{where: dynamic([p], p.score > p.base + 5)}
```
A raw `Ecto.dynamic` passed as a value is applied as-is. This is the only
genuinely Elixir-only path; the structured shapes above all travel over HTTP.

**v3.0.0 changes to this language (see §0.4):**
- **A bare list is sugar for `eq`, and `eq`+list routes by column type (D-LIST).**
  A bare list (`%{x: ["a","b"]}`) is the same as `%{x: %{eq: ["a","b"]}}`. On a
  **scalar** column that means **membership** — `x IN ("a","b")`. On a **list**
  column it means **exact array equality** — `x = ["a","b"]`. To ask whether a list
  column *overlaps* a list (shares any element), use the explicit **`overlaps`**
  operator (`%{tags: %{overlaps: ["a","b"]}}` → `tags && [...]`). `:in` is a
  scalar-membership operator; used on a **list** column it warns-and-skips (use
  `overlaps` or `eq`). The `:elements` wrapper is gone.
- **Date-math is a map, not a tuple, and "add" is "shift" (D-WIRE).** Write
  `%{ago: %{count: 1, unit: "day"}}`. To move a timestamp by an interval the word
  is `shift` (`%{date: %{shift: %{count: 7, unit: "day"}}}`) — distinct from the
  arithmetic `add` operand (§1.5a), so the two never clash. (A tuple is still
  accepted from Elixir for convenience; the canonical form is the map.)
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

The Elixir/atom form is canonical (shown first); the JSON form is the same shape
with string keys and ISO-text values.

| Kind | How you write it (Elixir) | Means | JSON form |
|---|---|---|---|
| Literal | `5` / `"x"` / `%{value: 5}` | a value, cast by the schema | bare scalar, or `{"value": 5}` |
| Column | `%{field: :other}` | another column on the **current** binding | `{"field": "other"}` |
| Sibling column | `%{field: :other, as: :author}` | a column on **another joined binding** in the same query | `{"field": "other", "as": "author"}` |
| Subquery | `%{from: Comment, where: %{…}}` | a source + a nested filter | `{"from": "comments", "where": {…}}` |
| Correlated | `%{parent: %{as: :post, field: :id}}` | an outer query's column (inside a subquery) | `{"parent": {"as": "post", "field": "id"}}` |

Rules:
- A bare scalar is sugar for `%{value: ...}`. (This also resolves the one
  ambiguity from prior art: to match a JSON column against a literal map, write
  `%{value: %{...}}` explicitly.)
- **Sibling-binding reference (D-SIBLING).** `%{field: :col, as: :binding}` points
  at a column on another joined binding in the *same* query (no `as:` = the
  current binding). The same `as:` qualifier works as a comparison's right-hand
  side, in `:select`, and in `:order_by` (§3.4); to *filter* on a sibling column,
  re-point the group with `:as`/`:at`. The binding name is validated against the
  query's bindings (§3.11). This is *sideways* (a peer in this query), distinct
  from `parent`, which reaches *outward* to an enclosing query.
- **Calculations** are expression trees with **ordered-list** operands, so
  `subtract`/`divide` are unambiguous and nothing is a tuple on the wire:
  `%{add: [%{field: :base}, %{value: 5}]}`, and they nest:
  `%{add: [%{mul: [%{field: :base}, %{value: 2}]}, %{value: 5}]}`. Math words:
  `add subtract multiply divide`. (Date *shifting* is a separate word, `shift`,
  inside a `:date`/`:datetime` wrapper — see §1.5 — so it never collides with
  arithmetic `add`.)
- **Subquery sources.** From Elixir, the source may be a schema **module**
  (`from: Comment`). From an HTTP request it must be a **registered string alias**
  (`"comments"`) — a client can never name a raw module (D-WIRE). The nested
  `where` is decoded against that source's schema.
- **Correlated `parent`** is only valid inside a subquery/`exists`. A subquery's
  `from` may declare a binding name (`%{from: Comment, as: :post, where: …}`);
  a descendant references it via `%{parent: %{as: :post, field: …}}`. The binding
  name is checked against the names declared by enclosing blocks **in the same
  request** — a client cannot invent one.

This one convention is what keeps the whole language to a single mental model
(`%{column: %{operator: operand}}`) and makes the advanced tier HTTP-encodable.

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
**The Elixir/atom form is the first-class shape** — a filter is most naturally an
Elixir map with atom keys (`%{age: %{gt: 21}}`), schema modules, and so on. HTTP
support is layered *on top* of that: a request decodes into the same shape, with
the string-and-text accommodations below. So when something can be an atom, the
canonical and typical form is the atom; strings are what arrive over the wire.

A request arrives as JSON (everything is text; there are no atoms or tuples) or as
a query string. The rules that make this clean:

- **Operator keys may be strings.** `{"age": {"gt": 21}}` decodes to the canonical
  `%{age: %{gt: 21}}`. Operator strings are turned into operators through a
  **fixed safe list** — the library never calls `String.to_atom` on caller input,
  so a malicious client cannot exhaust the atom table.
- **Atom keys are trusted; text keys are gated.** An Elixir caller passing atom
  keys is trusted (the atom already exists). Text keys — what HTTP delivers — are
  checked against the schema or `:allowed_keys` before use (§3.3).
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
date-math: :ago :from_now :shift, wrapped in :date or :datetime
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

A few naming notes about the tidied form:
- `nin` tidies to a negated `:in` (it has no separate tidied operator).
- the date-math caller key `unit` becomes `interval` in the tidied keyword list
  (`%{count: 1, unit: "day"}` → `[count: 1, interval: "day"]`).
- the arithmetic words map to symbols: `add`→`:+`, `subtract`→`:-`,
  `multiply`→`:*`, `divide`→`:/`.

### 2.3 The translator (the "resolver") — one place, no SQL, no database brand
A new piece — `EctoShorts.QueryBuilder.TermResolver` — does all the tidying. It
contains no SQL and knows nothing about any specific database. It only knows how to
convert values and read the schema.

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
| `%{id: [1,2]}` | `{"id":[1,2]}` | `:id` · no · `{:==,[1,2]}` · scalar | id is one of `^[1,2]` *(bare list = `eq`; on a scalar column → membership/IN — D-LIST)* |
| `%{published: %{ne: [true]}}` | `{"published":{"ne":[true]}}` | `:published` · no · `{:!=,[true]}` · scalar | published not one of `^[true]` *(nulls excluded — D-NULL)* |
| `%{title: %{ilike: "al"}}` | `{"title":{"ilike":"al"}}` | `:title` · no · `{:ilike,"%al%"}` · scalar | title contains "al", any case *(auto-`%` — D-LIKE-WRAP)* |
| `%{title: %{ilike: "al%"}}` | `{"title":{"ilike":"al%"}}` | `:title` · no · `{:ilike,"al%"}` · scalar | title starts with "al" *(your `%` kept)* |
| `%{title: %{eq: %{downcase: "AL"}}}` | `{"title":{"eq":{"downcase":"AL"}}}` | `:title` · no · `{:==,{:lower,"AL"}}` · scalar | lower(title) = "AL" |
| `%{views: %{avg: %{gt: 10}}}` | `{"views":{"avg":{"gt":10}}}` | `:views` · no · `{:avg,{:>,10}}` · scalar | avg(views) > `^10` |
| `%{at: %{gt: %{ago: %{count: 1, unit: "day"}}}}` | `{"at":{"gt":{"ago":{"count":1,"unit":"day"}}}}` | `:at` · no · `{:>,{:datetime,{:ago,[count: 1,interval: "day"]}}}` · scalar | at > the time 1 day ago *(map+`unit`, not a tuple — D-WIRE)* |
| `%{at: %{gt: %{date: %{shift: %{count: 7, unit: "day"}}}}}` | `{"at":{"gt":{"date":{"shift":{"count":7,"unit":"day"}}}}}` | `:at` · no · `{:>,{:date,{:shift,[count: 7,interval: "day"]}}}` · scalar | at's date > a date shifted 7 days *(`shift`, not `add` — D-ADD-SHIFT)* |

**Core — list columns, JSON columns, shorthands**
| Elixir | JSON body | tidied | Condition |
|---|---|---|---|
| `%{tags: ["a","b"]}` | `{"tags":["a","b"]}` | `:tags` · no · `{:==,["a","b"]}` · array | tags `=` `^["a","b"]` *(bare list = `eq`; on a list column → exact equality — D-LIST)* |
| `%{tags: "a"}` | `{"tags":"a"}` | `:tags` · no · `{:==,"a"}` · array | `^"a"` is an element of tags *(scalar vs list column → membership)* |
| `%{tags: %{overlaps: ["a","b"]}}` | `{"tags":{"overlaps":["a","b"]}}` | `:tags` · no · `{:overlaps,["a","b"]}` · array | tags shares a value with `^["a","b"]` (`&&`) *(explicit — D-LIST)* |
| `%{tags: %{in: ["a","b"]}}` | `{"tags":{"in":["a","b"]}}` | `:tags` · no · `{:in,["a","b"]}` · array | **warns and skips** *(`:in` is scalar-only; use `overlaps`/`eq` on a list column — D-LIST)* |
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
| `%{level: %{lt: %{field: :level, as: :author}}}` | `{"level":{"lt":{"field":"level","as":"author"}}}` | `:level` · no · `{:<,{:field,{:author,:level}}}` · scalar | this level < the joined `author` binding's level *(sibling binding — D-SIBLING)* |
| `%{score: %{gt: %{add: [%{field: :base}, %{value: 5}]}}}` | `{"score":{"gt":{"add":[{"field":"base"},{"value":5}]}}}` | `:score` · no · `{:>,{:+,[{:field,:base},{:value,5}]}}` · scalar | score > (base + `^5`) |
| `%{id: %{eq: %{all: %{from: Comment, where: %{published: true}}}}}` | `{"id":{"eq":{"all":{"from":"comments","where":{"published":true}}}}}` | `:id` · no · `{:==,{:all,«subq»}}` · scalar | id = every value the subquery returns *(Elixir: module; HTTP: alias)* |
| `%{exists: %{from: Comment, where: %{approved: true}}}` | `{"exists":{"from":"comments","where":{"approved":true}}}` | — · no · `{:exists,«subq»}` · common | rows that have a matching comment |
| `%{exists: %{from: Comment, as: :post, where: %{post_id: %{eq: %{parent: %{as: :post, field: :id}}}}}}` | `{"exists":{"from":"comments","as":"post","where":{"post_id":{"eq":{"parent":{"as":"post","field":"id"}}}}}}` | … `{:==,{:parent,{:post,:id}}}` … | comment.post_id = the outer post's id *(correlated)* |

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

> **On case transforms:** in the tidied `{:==, {:lower, "AL"}}`, the `:lower` marks
> a *column-side* operation — it reads "lowercase the column, then compare to
> `"AL"`" (SQL `lower(title) = 'AL'`). The transform always applies to the column,
> regardless of where it sits in the tuple.

### 2.6 Common "how do I …?" patterns
Concrete answers to everyday questions, to anchor the language:

| Goal | Filter |
|---|---|
| age over 21 and name contains "smith" | `%{age: %{gt: 21}, name: %{ilike: "smith"}}` |
| posts whose author is verified | `%{author: %{verified: true}}` *(association name → join + nested filter, §1.4)* |
| tags overlapping ["a","b"] | `%{tags: %{overlaps: ["a", "b"]}}` |
| created in the last 7 days | `%{inserted_at: %{gt: %{ago: %{count: 7, unit: "day"}}}}` |
| editor level above author level (both joined) | `%{editor_level: %{gt: %{field: :level, as: :author}}}` |
| trim whitespace before matching a name | `%{name: %{eq: %{trim: "smith"}}}` *(→ `trim(name) = "smith"`)* |
| select the author's name alongside posts | `%{select: %{author_name: %{field: :name, as: :author}}}` |
| order by the author's last name | `%{order_by: %{field: :last_name, as: :author}}` |

(For the sibling-binding cases, the `author`/`editor` bindings come from joining
those associations — an association name in the params, or an explicit `:join`.)

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
  ├─ structural words (§1.4) → hand to the matching builder module   (mostly unchanged)
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
`:field_types` entry for the column, the column is treated as scalar — a bare list
is `eq`+list → membership (`IN`), and the list-only operators (`overlaps`, list
`count`) warn-and-skip naming `:field_types` (§3.11).

On a column the array helper does handle (a known list type): a bare list is
`eq`+list → **exact array equality**; `overlaps` → `&&`; a scalar value →
element membership (`value IN array`); and `:in` (a scalar-membership operator)
**warns-and-skips** — list overlap is spelled `overlaps`, exact equality `eq`
(D-LIST).

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

**Sibling-binding references (D-SIBLING).** When a query has more than one joined
binding, a column can be qualified with `as:` to point at a *peer* binding in the
same query (§1.5a). The translator supports this `as:` qualifier in three places,
validated against the query's bindings (see §3.11 for when):
- the **right-hand side** of a comparison — `%{a: %{gt: %{field: :level, as: :author}}}`
- **selecting** — `%{select: %{author_name: %{field: :name, as: :author}}}`
- **ordering** — `%{order_by: %{field: :last_name, as: :author}}`
To *filter* directly on a sibling binding's column (left-hand side), use the
`:as`/`:at` selector, which re-points a whole filter group at that binding —
there is no left-side operand form. This `as:` is distinct from `parent` (which
reaches outward to an enclosing query); it reaches sideways to a peer binding in
the current query.

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

### 3.8 The structural filters (behavior preserved, except the two D-RAISE cases)
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
  - **a value of the wrong shape for its filter** — e.g. a `:lock` value that is
    not `%{name: …}`, or `:reverse_order` given anything other than `true`;
  - **an ordering operator (`gt`/`gte`/`lt`/`lte`) given `nil`** (e.g.
    `%{published_at: %{gt: nil}}`) — comparing order against nothing cannot be
    intended (only `eq`/`ne` accept `nil`, as the "has a value" check);
  - a `:lock` or `:join` provider hook that returns an **out-of-contract** shape
    or a function of the wrong arity (see §3.10). A provider's in-contract
    `{:error, reason}` return is *not* a raise — it warns and skips.

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

### 3.11 Detailed edge-case semantics (resolved from the spec review)
These rules close gaps a coherence review found. They are part of the contract.

**Aggregate placement.** An aggregate value-test (`%{views: %{avg: %{gt: 5}}}`)
always emits into **HAVING**, regardless of whether it was written under `:where`,
a bare column key, or `:having`. If the params contain no `:group_by`, the library
**adds a default GROUP BY** (the source's primary key) so the SQL is valid. (An
explicit `:group_by` is respected as-is.)

**Null semantics, per operator (D-NULL).** Only `eq nil` / `ne nil` consider null
rows (the "has a value" / "has no value" checks). **Every other operator emits
plain SQL**, so null rows are simply excluded by SQL's three-valued logic — this
covers `in`, `nin`, `overlaps`, ordering operators, and aggregate comparisons
alike. A `nil` *inside* an `in`/`nin` list (`%{id: %{in: [1, nil, 2]}}`) is a
malformed value and **raises** (§3.9) — write `%{or: [%{id: %{in: [1,2]}}, %{id: %{eq: nil}}]}`.

**Negation (toggle and compose).** The `negated` slot flips a condition.
Negation composes: nested `not` toggles (two cancel out), `%{not: %{in: […]}}` is
exactly the same as `nin`, and `not` around an `exists` becomes `NOT EXISTS`. No
expression is rejected for "too much not."

**Operand limits.**
- **Arithmetic is binary** — `add`/`subtract`/`multiply`/`divide` take **exactly
  two** operands; more raises. Nest for deeper math:
  `%{add: [%{mul: [a, b]}, c]}`.
- The validate step enforces a **max operand-tree depth** (configurable; see
  limits below) so a hostile JSON body cannot nest without bound.
- `in` / `nin` / `overlaps` take a **literal list** or a **subquery** operand
  only — not a `field`/`parent`/arithmetic operand.
- A `value` operand is **always a single literal** (never re-read as membership):
  `%{tags: %{eq: %{value: ["a","b"]}}}` is exact array equality, while
  `%{tags: ["a","b"]}` is membership.

**Sibling `as:` validation (D-SIBLING).** A sibling-binding reference is validated
in a **post-build pass**, after all joins exist (so order within the filter loop
doesn't cause false failures). An unknown or ambiguous binding name **raises**. A
sibling `as:` is **local to its operand** — it does not move the loop's current
binding. It is allowed on a comparison's right-hand side, in `:select`, and in
`:order_by` (left-hand filtering on a sibling uses the `:as`/`:at` selector
instead — §3.4).

**Correlated `parent`.** `parent` **requires** `as:` (no implicit nearest query).
The name resolves against the nearest enclosing block that declares it; on a name
collision across nesting levels, the innermost wins.

**Schemaless sources without `:field_types`.** With no known column type, a bare
list is treated as membership (§3.4). An **explicit list/JSON operator**
(`overlaps`, `contains`, `has_key`, `has_any_key`, `has_all_keys`, list `count`) on
a column of unknown type **warns and skips**, with a message naming `:field_types`
as the fix. (Schema-backed columns are unaffected — their type is known.)

**Date-math units.** `ago`, `from_now`, and `shift` all take `%{count: integer,
unit: u}`. `unit` is a **closed set** — `:second :minute :hour :day :week :month
:year` — decoded through the safe list (never `String.to_atom` on caller input).

**Validate-step limits.** The validate step enforces, with configurable defaults:
max filter nesting depth, max `or`/`and` branches, max list length, and max
operand-tree depth. These exist to bound the cost of an untrusted request; the
exact default values are settled when the validate step is built (§8).

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
| D-SIBLING | No way to reference a sibling binding's column within one query. | **Change (new capability)** | §1.5a/§3.4. A `field` operand gains an optional `as: :binding` qualifier (peer binding in the same query), usable on the right-hand side, left-hand side, `:select`, and `:order_by`. Distinct from `parent` (outer query). |
| D-ELIXIR-FIRST | HTTP-leaning framing implied strings were primary. | **Change (framing)** | §1.7 / tenet 12. Atoms/modules are the canonical, typical form; HTTP strings decode into them. Atom keys from Elixir are trusted; text keys are gated (§3.3). |
| D-ADD-SHIFT | Date-math and arithmetic both used `add`. | **Change (breaking)** | §1.5/§1.5a. Date shifting is `shift` (inside a `:date`/`:datetime` wrapper); `add` is arithmetic only. No clash. |
| D-TRIM | `trim`/`ltrim`/`rtrim` absent. | **Change (add)** | §1.5. Added to the text transforms alongside `lower`/`upper`. |
| D-WIRE | The language assumed Elixir atoms/tuples; HTTP decoding was unspecified. | **Change (breaking)** | §1.7. Operator keys may be strings (closed safe list, never `String.to_atom`); date-math is a map not a tuple; subquery sources are registered names not modules; times are ISO 8601. |
| D-LIST | List behavior needs `:elements`; a plain list vs an `:in` list mean different things on a list column. | **Change (breaking)** | §0.4/§3.4/§3.11. Remove `:elements`. A bare list is sugar for `eq`; `eq`+list routes by column type — scalar → membership (`IN`), list column → exact array equality. Overlap is the explicit `overlaps` operator; `:in` on a list column warns-and-skips. |
| D-RAISE | Caller mistakes are silently warned-and-skipped (scalar association, bad binding, `:reverse_order` with no order, malformed value shapes, ordering-operator-vs-nil, out-of-contract provider return). | **Change (breaking)** | §3.9. From Elixir these raise (a bug). Untrusted HTTP input is validated first and returns errors as data, so a bad request is a 4xx, not a crash. An in-contract provider `{:error, reason}` still warns-and-skips. |
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
