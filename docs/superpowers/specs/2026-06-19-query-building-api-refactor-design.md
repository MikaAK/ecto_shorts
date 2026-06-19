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
- We are **not** changing the filters callers write. Every map shape that works
  today keeps working exactly the same way (§1).
- We are **not** adding support for other databases. We make the translator
  database-agnostic so another could be added later, but only PostgreSQL ships.
- We are **not** changing how errors are handled, except where §4 explicitly says
  so. "Log a warning and skip" stays the behavior.

### 0.3 The rules we follow (from `RULES.md`)
- **Depend on promises, not on inner workings.** Each boundary below is described
  by what goes in and what comes out, not by how it happens to be coded today.
- **Write the plan before the code.** This document is that plan. No code is
  written until it is approved.
- **Show the actual values, not just descriptions.** Every translation below shows
  a real "before" and "after."

---

## 1. THE PROMISE TO CALLERS — `EctoShorts.CommonFilters.convert_params_to_filter/3`

This is the front door. Other people's code calls it; it must keep behaving
exactly as it does today.

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
A single query with every recognized filter applied. **It never crashes because of
an unknown column or an unsupported combination** — it logs a warning and skips
that filter. (There is one audited exception, noted in §4.)

### 1.4 The filters callers may write (the full, frozen list)
These are the structural filter words the library recognizes:
```
:and :distinct :except :except_all :exclude :first :group_by :having
:intersect :intersect_all :join :last :limit :lock :offset :or :or_having
:or_where :page :prepend_order_by :preload :put_query_prefix :recursive_ctes
:reverse_order :select :select_merge :subquery :union :union_all :update
:where :windows :with_cte :with_named_binding :with_ties
```
Two special words pick which table a filter points at: `:as` and `:at`.
Anything else is handled automatically: a key that names an **association** turns
into a join plus a nested filter; any **other** key is treated as a column filter
(the same as putting it under `:where`).

> The full table of every filter word — what shapes it accepts, what it adds to the
> query, and when it warns-and-skips — lives in `inventory/01-common-filters.md`,
> section 7. The rewrite must keep every row of that table the same, except where
> §4 says otherwise.

### 1.5 The filter-value language (the part this rewrite reshapes inside)
Inside `:where`, `:or_where`, `:having`, `:or_having`, `:and`, `:or`, and plain
column keys, a column maps to a **value test**. Here is the full set of value
tests callers can write (callers depend on this; it does not change):

```
A value test can be:
  a plain value          %{id: 1}                  → id equals 1
  nothing (nil)          %{published_at: %{eq: nil}} → published_at has no value
  a list                 %{id: [1, 2]}             → id is one of 1, 2
  an operator + value    %{age: %{gt: 21}}         → age greater than 21
  "not" + a value test   %{age: %{not: %{eq: 5}}}  → age is not 5
  an aggregate test      %{views: %{avg: %{gt: 5}}} → average of views greater than 5
  a compare-to-a-set     %{id: %{eq: %{all: ...}}}  → id equals every value from a subquery
  a computed-field test  %{score: %{arithmetic: ...}}  → compare against a calculation
  an aggregate wrapper    %{score: %{aggregate: ...}}   → another way to write an aggregate test
  a force-list wrapper    %{tags: %{elements: ...}}     → treat the column as a list
  a right-hand expression %{a: %{gt: %{field: :b}}}      → compare one column to another
  a JSON test            %{data: %{has_key: "role"}}    → for columns that store JSON
  a date-math test       %{at: %{gt: %{ago: {1, :day}}}} → compare against "1 day ago", etc.
```

The operator nicknames listed in the glossary (`:gt`, `:downcase`, …) are part of
this public language and stay. Section 2 describes the **tidied** form we turn all
of this into inside the library.

### 1.6 The options it accepts
| Option | Meaning |
|---|---|
| `:field_types` | A list of `column → type`. Overrides the schema, and is required to get list/JSON behavior on schemaless sources. |
| `:allowed_keys` | When there is no schema, the list of column names (as text) the library is allowed to accept. |
| `:sorter` | Your own function to order the filters, replacing the built-in ordering. |
| `:dynamic_builder` | Use a different database-brand translator for this one call. |
| `:query_builder_module` | Use a different filter dispatcher for this one call. |
| (set in app config) | `:repo`, `:replica`, `:dynamic_builder_module`, `:query_builder_module`, `:query_provider_module`, `:error_module`, `:max_positional_bindings`. |

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

### 2.2 The complete list of tidied filter shapes
After tidying, every operator is a real symbol (no nicknames left), every value is
converted to the column's type, and any "not" has been pulled out into the
`negated` slot. The allowed shapes are exactly these — nothing else reaches a
helper:

```
operators (after tidying): :== :!= :> :>= :< :<=
aggregates: :avg :count :max :min :sum
compare-to-a-set words: :all :any        (every value / at least one value)
math words: :+ :- :* :/
date-math: :ago :from_now :add, wrapped in :date or :datetime
text-case words: :lower :upper

A tidied filter is one of:
  {operator, value}                         a plain comparison
  {operator, nil}                           a "has a value / has no value" check
  {:in, [values]}                           is one of a list
  {operator, [values]}                      list form of equals / not-equals
  {:like or :ilike, text or [texts]}        text pattern match
  {operator, {:lower or :upper, value}}     compare after lowercasing/uppercasing
  {aggregate, {operator, value}}            e.g. average greater than 5
  {operator, {:all or :any, set}}           compare against every/any value in a set
  {operator, {:date or :datetime, {date-math, [count, interval, maybe field]}}}
  {operator, {:value, {math, {{:field, col}, {:value, n}}}}}   a calculation
  {operator, {:parent_as, {table, col}}}    compare to a column in an outer query
  {:count, {operator, number}}              how many items in a list column
  {:all or :any, {operator or :in, value}}  list-column comparisons
  {:contains / :contained_by, ...}          JSON containment
  {:has_key / :has_any_key / :has_all_keys, ...}   JSON key checks
  {:ids, [..]} / {:before/:after/:since/:until, n} / {:exists, query}   shorthands
  {:start_date/:end_date/:since_date/:until_date, time}   date shorthands
```

**What the translator guarantees before any helper sees a filter:**
1. The operator is a real symbol — no nicknames like `:gt` or `:downcase` remain.
2. Every value has already been converted to the column's type.
3. The column is an atom; if it came in as text, it has been resolved and checked.
4. Any "not" has been pulled out into the `negated` slot, exactly once.
5. The helper to use (scalar / array / map / common) has already been chosen.
6. The convenience wrappers (`:arithmetic`, `:aggregate`, `:elements`, the date
   wrappers, and shorthands like `:ids` or `:start_date`) have been expanded into
   the plain shapes above — **and the column a shorthand implies has been filled
   in** (for example `:ids` carries `:id`, `:start_date` carries `:inserted_at`),
   so the helpers never have to assume a column name.

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
canonical_op(raw_op)            # turns a nickname into the real operator
resolve_field(source, name, opts)   # turns a column name into a checked atom, or :skip
routing_family(source, field, opts) # decides scalar / array / map / common
cast(field_type, value)         # converts a value to the column's type
```

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

Each row shows three things: the **filter a caller writes** (left), the **tidied
filter** the translator produces (middle: which column · whether it is negated · the
tidied operator-and-value · which helper), and **the database condition it becomes**
(right). The examples use a sample `Post` table with columns `views` (number),
`title` (text), `published` (true/false), `tags` (a list of text), and
`inserted_at`/`published_at` (timestamps); plus a `UserData` table with a `data`
column that stores JSON. Conditions are shown in a short readable form; `^x` marks a
value that is filled in safely at run time.

**Plain comparisons, "has a value" checks, and lists — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{id: 1}` | `:id` · no · `{:==, 1}` | id equals `^1` |
| `%{views: %{gt: 10}}` | `:views` · no · `{:>, 10}` | views greater than `^10` |
| `%{published_at: %{eq: nil}}` | `:published_at` · no · `{:==, nil}` | published_at has no value |
| `%{published_at: %{ne: nil}}` | `:published_at` · no · `{:!=, nil}` | published_at has a value |
| `%{published: %{in: [true, false]}}` | `:published` · no · `{:in, [true, false]}` | published is one of `^[true, false]` |
| `%{published: [true, false]}` | `:published` · no · `{:==, [true, false]}` | published is one of `^[true, false]` *(a plain list means "is one of")* |
| `%{published: %{ne: [true]}}` | `:published` · no · `{:!=, [true]}` | published has no value OR is not one of `^[true]` *(see decision D-NEQ-LIST)* |

**Text matching and upper/lowercasing — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{title: %{like: "hello"}}` | `:title` · no · `{:like, "%hello%"}` | title contains "hello" *(the `%` are added automatically; see D-LIKE-WRAP)* |
| `%{title: %{like: "hello%"}}` | `:title` · no · `{:like, "hello%"}` | title starts with "hello" *(you wrote your own `%`, so it is left as-is)* |
| `%{title: %{ilike: ["a", "b"]}}` | `:title` · no · `{:ilike, ["%a%", "%b%"]}` | title matches "a" or "b", ignoring upper/lowercase |
| `%{title: %{eq: %{downcase: "HELLO"}}}` | `:title` · no · `{:==, {:lower, "HELLO"}}` | lowercased title equals "HELLO" *(`:downcase` becomes `:lower`)* |

**Summaries of many rows (aggregates) — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{views: %{avg: %{gt: 10}}}` | `:views` · no · `{:avg, {:>, 10}}` | average of views greater than `^10` |
| `%{views: %{aggregate: %{fn: :sum, compare: :==, value: 1000}}}` | `:views` · no · `{:sum, {:==, 1000}}` | sum of views equals `^1000` |

**Compare against a set from a subquery — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{id: %{eq: %{all: %{from: Comment, where: %{published: true}}}}}` | `:id` · no · `{:==, {:all, «subquery»}}` | id equals every value returned by (a subquery over comments where published is true) |

**Date math — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{inserted_at: %{eq: %{ago: {1, :day}}}}` | `:inserted_at` · no · `{:==, {:datetime, {:ago, [count: 1, interval: "day"]}}}` | inserted_at equals the time 1 day ago |
| `%{published_at: %{gte: %{from_now: {1, :day}}}}` | `:published_at` · no · `{:>=, {:datetime, {:from_now, [count: 1, interval: "day"]}}}` | published_at is at or after the time 1 day from now |
| `%{inserted_at: %{gte: %{date: %{add: %{count: 7, interval: "day"}}}}}` | `:inserted_at` · no · `{:>=, {:date, {:add, [count: 7, interval: "day"]}}}` | the date part of inserted_at is at or after a date 7 days out |

**Calculations and comparing one column to another — helper: scalar**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{views: %{arithmetic: %{compare: :>, add: %{field: :id, value: 5}}}}` | `:views` · no · `{:>, {:value, {:+, {{:field, :id}, {:value, 5}}}}}` | views greater than (id + `^5`) |
| `%{post_id: %{parent_as: %{post: :id}}}` | `:post_id` · no · `{:parent_as, {:post, :id}}` | post_id equals the `id` column of the outer query's `post` table |

**List columns — helper: array** (a real list column like `tags`, or a schemaless
column forced to a list with `:elements` or declared with `:field_types`)
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{tags: %{in: ["a", "b"]}}` *(real list column)* | `:tags` · no · `{:in, ["a", "b"]}` | tags shares any value with `^["a","b"]` |
| `%{tags: %{elements: %{in: ["a", "b"]}}}` *(schemaless)* | `:tags` · no · `{:in, ["a", "b"]}` | same as above |
| `%{tags: "elixir"}` *(with `field_types: [tags: {:array, :string}]`)* | `:tags` · no · `{:==, "elixir"}` | "elixir" is one of the values in tags |
| `%{tags: %{elements: %{count: %{gt: 3}}}}` | `:tags` · no · `{:count, {:>, 3}}` | tags has more than `^3` items |
| `%{tags: %{elements: %{all: %{in: ["a"]}}}}` | `:tags` · no · `{:all, {:in, ["a"]}}` | every value in tags is inside `^["a"]` |

**JSON columns — helper: map** (the `data` column, or a column declared with
`:field_types`)
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{data: %{contains: %{role: "admin"}}}` | `:data` · no · `{:contains, {:role, "admin"}}` | the JSON in data contains `{role: "admin"}` |
| `%{data: %{contained_by: %{role: "admin"}}}` | `:data` · no · `{:contained_by, {:role, "admin"}}` | the JSON in data is contained within `{role: "admin"}` |
| `%{data: %{has_key: "role"}}` | `:data` · no · `{:has_key, "role"}` | the JSON in data has a key "role" |
| `%{data: %{has_any_key: ["a", "b"]}}` | `:data` · no · `{:has_any_key, ["a", "b"]}` | the JSON in data has at least one of these keys |

**Shorthands — helper: common** (the translator fills in the column these imply, so
the helper no longer assumes a column name; see §3.6 / D-CommonExpr-FIELD)
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{ids: [1, 2, 3]}` | `:id` · no · `{:ids, [1, 2, 3]}` | id is one of `^[1, 2, 3]` |
| `%{before: 100}` | `:id` · no · `{:before, 100}` | id less than `^100` |
| `%{after: 100}` | `:id` · no · `{:after, 100}` | id greater than `^100` |
| `%{start_date: t}` | `:inserted_at` · no · `{:start_date, t}` | inserted_at at or after `^t` |
| `%{end_date: t}` | `:inserted_at` · no · `{:end_date, t}` | inserted_at at or before `^t` |
| `%{exists: «subquery»}` | *(no column)* · no · `{:exists, «subquery»}` | rows for which the subquery returns anything |

**The "not" case — works on top of any shape above (the `negated` slot)**
| Filter a caller writes | column · negated · tidied | Database condition |
|---|---|---|
| `%{views: %{not: %{eq: 10}}}` | `:views` · **yes** · `{:==, 10}` | not (views equals `^10`) |
| `%{published: %{not: %{in: [true]}}}` | `:published` · **yes** · `{:in, [true]}` | published has no value OR is not one of `^[true]` |
| `%{published_at: %{not: %{eq: nil}}}` | `:published_at` · **yes** · `{:==, nil}` | published_at has a value |

> **How to read these tables.** The left column is what a caller actually types
> (with friendly nicknames like `eq`, `gt`, `downcase`). The middle column is the
> same filter after the translator has tidied it (real operators, converted values,
> a resolved column, the "not" pulled out). Turning the left column into the middle
> column is the translator's entire job.

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
Same as today: first look at `:field_types`, otherwise read the schema. A list
column → the array helper; a JSON/map column → the map helper; a shorthand word →
the common helper; everything else → the scalar helper. An unknown column → skip and
warn.

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
(§3.3); what callers see does not change.

---

## 4. DECISIONS — what we keep and what we change

**The most important rule (resolving the "what do we measure against?" question):**
correctness is measured against **this document**, not against the current code and
not against the current tests. Where a decision says *keep*, today's behavior is the
promise. Where it says *change*, this document wins and we update the code and tests
to match.

| ID | Today's behavior | Decision | Why |
|---|---|---|---|
| D-WARN | Unknown column / unsupported combination → log a warning and skip (37+ such cases in `inventory/04`, section 3). | **Keep** | A pure structural cleanup; the translator returning "skip" reproduces it. |
| D-API | The filters and options callers write (§1). | **Keep, frozen** | We promised no change to what callers see. |
| D-INTERNAL | Today's internal function names and shapes (`build_dynamic`, `apply_expr`, `dispatch_expr`, `cast_value`, `field_name_to_atom`, …). | **Free to change** | These are internal; they do not need to survive. |
| D1 | The 370-line comparison function and dozens of tiny builder clauses. | **Change (break up)** | §3.7. The conditions produced are identical. |
| D-NEQ-LIST | `%{field: %{ne: [a, b]}}` becomes "has no value OR is not one of [a, b]". | **Keep, and document** | Including "has no value" is deliberate; we will explain it in the code comments rather than change it. |
| D-LIKE-WRAP | `%{like: "x"}` becomes "contains x" by adding `%` signs, but `"x%"` is left alone. | **Keep, and document** | This is public behavior; we freeze it and describe it in §1.5. |
| D-ELEMENTS | On schemaless sources, list behavior needs `:elements`, unless `:field_types` is given. | **Keep** | Already a documented quirk; changing it is out of scope here. |
| D-PROVIDER | The "lock" and "join" provider hooks are loosely checked. | **Keep** | Out of scope; note it for a later, separate effort. |
| D-CommonExpr-FIELD | The shorthand helper assumes columns `id` and `inserted_at`. | **Change (internal only)** | §3.6 — the column is filled in earlier; the resulting condition is identical (still uses `id` / `inserted_at` for those shorthands). |

**Still to confirm during the work (not blocking this plan):** the remaining
questionable behaviors listed in `inventory/04`, section 5 are *keep-and-document* by
default. If any should actually change, we raise it during the test review (§5) and
add a row to this table first.

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
| `EctoShorts.CommonFilters` | filter-ordering becomes one pass; the main loop sends column conditions through the translator, then the adapter. What callers see does not change. |
| `EctoShorts.QueryBuilder.TermResolver` *(new, no database brand)* | the translator. Holds all the tidying that today is scattered across the PostgreSQL builder. |
| `EctoShorts.DynamicBuilders.Postgres` | shrinks to a thin adapter: take a tidied filter, pick the helper by `routing`, apply the "not." No tidying. |
| `EctoShorts.DynamicBuilders.Postgres.ScalarExpr` | becomes pure; the giant function is broken up (§3.7); the tiny builders collapse into one table. |
| `…ArrayExpr`, `…MapExpr` | already pure; now receive tidied filters only. |
| `…CommonExpr` | becomes pure; the column is passed in instead of assumed. |
| the structural filter modules | unchanged, except they share the one column-name helper. |

---

## 7. Things noted for later (not part of this work)
- Whether to crash loudly instead of warn-and-skip (D-WARN keeps warn-and-skip).
- Tightening the "lock" and "join" provider hooks (D-PROVIDER).
- Filling the thin test spots listed in `inventory/04`, section 4 (limit, recursive
  CTE depth, nested calculations, association links).
```
