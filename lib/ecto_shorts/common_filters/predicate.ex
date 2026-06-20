defmodule EctoShorts.CommonFilters.Predicate do
  @moduledoc """
  Describes a single filter condition after it has been fully resolved.

  In Elixir, a struct is a map with a fixed set of named fields. This struct
  carries everything a database adapter needs to know about one filter
  condition — which field to filter on, what kind of comparison to make,
  whether the condition is negated, and the value to compare against.

  When you pass filter params to
  `EctoShorts.CommonFilters.convert_params_to_filter/3`, each field-level
  condition is processed and turned into a `Predicate` struct by
  `EctoShorts.CommonFilters.PredicateBuilder`. The active
  `EctoShorts.DynamicBuilder` adapter then receives this struct and turns it
  into an Ecto `WHERE` clause.

  ## When you need this struct

  You only need to work with this struct if you are implementing a custom
  `EctoShorts.DynamicBuilder`. See that module for a complete guide.

  ## Fields

  * `:field` — the schema field name as an atom, for example `:title` or
    `:published_at`.
  * `:routing` — which family of expression builder handles this field. See
    `t:routing/0` for the possible values and what they mean.
  * `:negated` — `true` when the condition should be inverted. For example, a
    `not in` check is the negated form of an `in` check.
  * `:expr` — the operator and value to apply. For a simple equality check this
    is `{:==, value}`; for a greater-than comparison it is `{:>, value}`.
  """

  @enforce_keys [:field, :routing, :negated, :expr]
  defstruct [:field, :routing, :negated, :expr]

  @typedoc """
  Which family of expression builder handles this predicate.

  * `:scalar` — single-value comparisons, string operations, aggregates, and
    arithmetic. Handled by `EctoShorts.DynamicBuilders.Postgres.ScalarExpr`.
  * `:array` — Postgres array operators such as overlap (`&&`) and containment.
    Handled by `EctoShorts.DynamicBuilders.Postgres.ArrayExpr`.
  * `:map` — JSONB operators (`@>`, `<@`, `jsonb_exists`).
    Handled by `EctoShorts.DynamicBuilders.Postgres.MapExpr`.
  * `:common` — cursor-style pagination operators (`:before`, `:after`,
    `:since`, `:until`) and `:exists`. Handled by
    `EctoShorts.DynamicBuilders.Postgres.CommonExpr`.
  """
  @type routing :: :scalar | :array | :map | :common

  @typedoc """
  A fully resolved filter predicate.

  Produced by `EctoShorts.CommonFilters.PredicateBuilder` and consumed by the
  active `EctoShorts.DynamicBuilder` adapter.
  """
  @type t :: %__MODULE__{
          field: atom(),
          routing: routing(),
          negated: boolean(),
          expr: term()
        }
end
