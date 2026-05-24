## Rules & Constraints

Constraints that govern this plan. Every change to PLAN.md must be consistent with every rule below. When a new rule is added or an existing rule changes, audit the rest of the plan and update anything that no longer conforms.

1. Maintain this section. Keep it at the top of PLAN.md and keep it current.

---

## Projected final state of `lib/ecto_shorts/dynamic_builders/postgres.ex`

### Changes

| Removed | Reason |
|---|---|
| `alias EctoShorts.CommonFilters`, `alias EctoShorts.CommonFilters.Select` | No longer called from here (Change 2) |
| `build_quantified_query/3`, `subquery_spec?/1` | Moved to `CommonFilters` (Change 2) |
| `apply_expr/4` | Replaced by `walk/6` (Change 6) |
| `dispatch_expr/6` (all ~15 clauses) | Replaced by `walk/6` + `evaluate/6` (Change 6) |
| `dispatch_field_expr/6` | Renamed to `evaluate_field/6` with simplified body (Changes 3 + 6) |
| `field_type` resolution in `build_dynamic/4` | Moved to `resolve_field_type/3`; one call site (Change 1) |
| Per-clause `Enum.map \|> Enum.reduce` pairs | Collapsed into single `Enum.reduce` in `walk/6` (Changes 1 + 5) |
| `canonical = cond do ...` blocks in `dispatch_field_expr` | `evaluate_field/6` always receives `{op, value}` (Change 3) |
| `array_field?/3`, `map_field?/3` re-resolution | Take pre-resolved `field_type` (Change 3) |
| `cast_value/2` (all 14 clauses) | `Types.cast` called once directly in `evaluate_field/6` after all wrapper normalization completes |
| `build_rhs_entry/4` (all clauses) | Wrapper + Operand normalization now lives in `evaluate/6` (router), not a helper |
| `build_rhs_expr/3` (all clauses) | Same reason as `build_rhs_entry/4` |
| `resolve_datetime_wrapper/3`, `resolve_datetime_node/3` | Datetime wrapper normalization moves to an `evaluate/6` clause (router owns all wrapper normalization) |
| `:arithmetic` evaluator clause | Replaced by the Operand RHS shape, normalized in the router and dispatched by `ScalarExpr` tuple-IR clauses (Change 7) |
| All exact-shape matches (5 locations) | Entry-boundary reduces in the router, or `Map.fetch!`-style single-entry helpers (Changes 4a–4d + 2) |

| Added / changed visibility | Reason |
|---|---|
| `walk/6` | Single-pass traversal — top-level fan-out only, normalizes short-ops inline, AND/OR-merges dyns (Change 6). Signature `(source, binding, key, negated, term, opts)` aligned with `evaluate/6` and `evaluate_field/6`. |
| `evaluate/6` | Single routing + normalization function. One clause per public-API shape. Owns datetime-wrapper normalization, `parent_as` normalization, Operand RHS tree normalization (recursive map-to-tuple), transform/aggregate/elements/quantifier normalization, and generic map-to-keyword-list fan-out for non-Operand comparison RHS (Changes 6 + 7). Same aligned signature. |
| `evaluate_field/6` | Field-level router; single call site for `Types.cast/2` in the entire module. Receives only tuple IR (Changes 3 + 6). Same aligned signature. |
| `resolve_field_type/3` | Single call site for field type resolution (Change 1) |
| `normalize_op/1` | Short-op alias table used inline at each lift in `walk/6` |
| `@transform_ops`, `@datetime_wrappers`, `@comparison_operators` module attributes | Explicit guard lists for evaluator clauses |
| `@operand_leaf_keys`, `@operand_variadic_keys`, `@operand_binary_keys`, `@operand_unary_keys`, `@operand_keys` | Operand grammar keys for the router's Operand-shape detection and normalization (Change 7) |
| `operand_shape?/1`, `normalize_operand/3`, `normalize_field_leaf/3`, `normalize_variadic/4`, `normalize_binary/4`, `normalize_unary/4`, `normalize_operand_list/4` | Private helpers implementing Operand-tree normalization in the router (Change 7) |
| `arity_warn/3`, `warn_unknown_operand/1` | Private helpers for skip + warn paths in the Operand normalizer |
| `field_name_to_atom/3` stays **private** | Called only by `normalize_field_leaf/3` in the router's Operand normalizer. Sub-modules never call it; they receive atoms in tuple IR. |

### Final state

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres do
  @moduledoc """
  Build Postgres-specific dynamic filter expressions.
  ...
  """

  import Ecto.Query, only: [dynamic: 1]

  alias EctoShorts.{
    CommonSchema,
    DynamicBuilders.Postgres.ArrayExpr,
    DynamicBuilders.Postgres.CommonExpr,
    DynamicBuilders.Postgres.MapExpr,
    DynamicBuilders.Postgres.ScalarExpr,
    Types
  }

  @behaviour EctoShorts.DynamicBuilder

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres"

  # ── Module attributes ────────────────────────────────────────────────
  # Operator and wrapper-key vocabularies. Used as guard-set membership
  # checks throughout the evaluator. Sub-modules don't reference these;
  # they receive normalized tuple IR in which all wrapper names have
  # already been canonicalized.

  @quantifier_operators [:all, :any]
  @common_expr_operators CommonExpr.operators()
  @short_ops [:eq, :ne, :gt, :gte, :lt, :lte]
  @comparison_operators [:==, :!=, :>, :>=, :<, :<=]
  @agg_fns [:avg, :sum, :max, :min, :count]
  @transform_ops [:lower, :upper, :downcase, :upcase]
  @datetime_wrappers [:date, :datetime]

  # Operand grammar keys (Change 7). Single-key Operand maps in a
  # comparison RHS use one of these keys to identify the operand kind.
  # The router owns Operand-tree normalization; sub-modules (ScalarExpr)
  # receive fully-normalized tuple IR.
  @operand_leaf_keys [:field, :value]
  @operand_variadic_keys [:add, :subtract, :multiply, :divide]
  @operand_binary_keys [:power, :mod]
  @operand_unary_keys [:abs, :round, :floor, :ceil, :sqrt]
  @operand_keys @operand_leaf_keys ++
                  @operand_variadic_keys ++ @operand_binary_keys ++ @operand_unary_keys

  # ── build_dynamic/4 ──────────────────────────────────────────────────
  # Public entry point. Implements EctoShorts.DynamicBuilder for Postgres.
  # Returns a dynamic expression for the given filter entry, or nil when
  # every child predicate skipped.
  #
  # build_dynamic(Post, {:as, nil}, {:views, 5}, [])
  #   ⇒ dynamic([p], p.views == 5)
  #
  # build_dynamic(Post, {:as, nil}, {:any, [published: true, archived: false]}, [])
  #   ⇒ dynamic([p], p.published == true or p.archived == false)
  #
  # build_dynamic(Post, {:as, nil}, {:all, [views: 5, archived: false]}, [])
  #   ⇒ dynamic([p], p.views == 5 and p.archived == false)
  #
  # build_dynamic({"posts", nil}, {:as, nil}, {:tags, ["a"]},
  #               field_types: [tags: {:array, :string}])
  #   ⇒ dynamic([p], "a" in p.tags)
  #
  # build_dynamic(Post, {:at, 2}, {:title, "x"}, [])
  #   ⇒ dynamic([_, _, p], p.title == "x")
  #
  # build_dynamic(Post, {:as, :author}, {:name, "Alice"}, [])
  #   ⇒ dynamic([author: a], a.name == "Alice")
  #
  # build_dynamic(Post, {:as, nil},
  #               {:score, %{gt: %{add: [%{field: :base}, %{value: 5}]}}}, [])
  #   ⇒ dynamic([p], p.score > p.base + 5)
  #
  # build_dynamic(Post, {:as, nil}, {:title, %{}}, [])    # empty wrapper, no children
  #   ⇒ nil
  @impl true
  @spec build_dynamic(term(), {:as, nil | atom()} | {:at, pos_integer()}, term(), keyword()) ::
          Ecto.Query.dynamic_expr() | nil
  def build_dynamic(source, selected_binding, args, opts \\ [])

  # Quantifier head — top-level :all / :any group. Reduces over `params`,
  # building one child dyn per entry, merging via the requested
  # quantifier (:and for :all, :or for :any). The outer merge_dynamic/3
  # call wraps the aggregate to keep parenthesization explicit when the
  # caller composes this with other dyns.
  def build_dynamic(source, selected_binding, {quantifier_op, params}, opts)
      when quantifier_op in @quantifier_operators do
    expr =
      Enum.reduce(params, nil, fn {key, term}, acc ->
        dyn = build_dynamic(source, selected_binding, {key, term}, opts)
        merge_dynamic(acc, quantifier_op, dyn)
      end)

    merge_dynamic(nil, :and, expr)
  end

  # Ordinary entry head — single {key, term}. Hands off to walk/6 with
  # negated=nil; walk/6 handles map / kwlist / tuple / scalar value shapes.
  def build_dynamic(source, selected_binding, {key, params}, opts) do
    dyn = walk(source, selected_binding, key, nil, params, opts)
    merge_dynamic(nil, :and, dyn)
  end

  # ── walk/6 ───────────────────────────────────────────────────────────
  # Single-pass, top-level fan-out walker. Routes the value slot of a
  # {key, value} entry into evaluate/6, fanning out maps and keyword
  # lists into per-entry sub-calls. Returns a dynamic expression or nil.
  #
  # The walker does NOT descend into tuple inners: wrapper payloads
  # (:aggregate, :elements) and Operand RHS trees reach the evaluator
  # intact, where the owning clause or sub-module handles them. Short-op
  # aliases (:eq → :==, etc.) are normalized inline at each entry lift
  # via normalize_op/1.

  # Map clause — convert to keyword list and re-enter.
  #
  # walk(Post, {:as, nil}, :views, nil, %{gt: 5, lt: 10}, [])
  #   ⇒ walk(Post, {:as, nil}, :views, nil, [gt: 5, lt: 10], [])
  #   ⇒ dynamic([p], p.views > 5 and p.views < 10)
  defp walk(source, binding, key, negated, v, opts)
       when is_map(v) and not is_struct(v) do
    walk(source, binding, key, negated, Map.to_list(v), opts)
  end

  # List clause. Non-empty keyword lists fan out: one dyn per entry,
  # AND-merged by default. {:and, term} / {:or, term} entries lift
  # their inner term into a sub-walk merged with the parent acc using
  # the requested operator. Non-keyword lists fall through as a single
  # equality (membership) operand.
  #
  # walk(Post, {:as, nil}, :views, nil, [gt: 5, lt: 10], [])
  #   ⇒ dynamic([p], p.views > 5 and p.views < 10)
  #
  # walk(Post, {:as, nil}, :views, nil, [or: [gt: 100], lt: 5], [])
  #   ⇒ dynamic([p], p.views > 100 or p.views < 5)
  #
  # walk(Post, {:as, nil}, :tags, nil, ["red", "blue"], [])
  #   # non-keyword list → equality with the list as RHS
  #   ⇒ evaluate(... {:==, ["red", "blue"]}, ...)
  defp walk(source, binding, key, negated, v, opts) when is_list(v) do
    if Keyword.keyword?(v) and v !== [] do
      Enum.reduce(v, nil, fn entry, acc ->
        {merge_op, lifted} =
          case entry do
            {op, term} when op in [:and, :or] -> {op, term}
            {k, child} -> {:and, {normalize_op(k), child}}
          end

        dyn = walk(source, binding, key, negated, lifted, opts)
        merge_dynamic(acc, merge_op, dyn)
      end)
    else
      evaluate(source, binding, key, negated, {:==, v}, opts)
    end
  end

  # Tuple clause — hand to evaluate/6 unchanged.
  #
  # walk(Post, {:as, nil}, :views, nil, {:>, 5}, [])
  #   ⇒ evaluate(Post, {:as, nil}, :views, nil, {:>, 5}, [])
  #   ⇒ dynamic([p], p.views > 5)
  defp walk(source, binding, key, negated, {_, _} = v, opts) do
    evaluate(source, binding, key, negated, v, opts)
  end

  # Bare scalar — wrap as equality.
  #
  # walk(Post, {:as, nil}, :views, nil, 5, [])
  #   ⇒ evaluate(Post, {:as, nil}, :views, nil, {:==, 5}, [])
  #   ⇒ dynamic([p], p.views == 5)
  defp walk(source, binding, key, negated, value, opts) do
    evaluate(source, binding, key, negated, {:==, value}, opts)
  end

  # ── normalize_op/1 ───────────────────────────────────────────────────
  # Short-op alias resolver, used by the kwlist fan-out in walk/6 to
  # canonicalize operator keys at lift time.
  #
  # normalize_op(:eq)  ⇒ :==
  # normalize_op(:ne)  ⇒ :!=
  # normalize_op(:gt)  ⇒ :>
  # normalize_op(:gte) ⇒ :>=
  # normalize_op(:lt)  ⇒ :<
  # normalize_op(:lte) ⇒ :<=
  # normalize_op(:in)  ⇒ :in    # not a short-op, passes through
  # normalize_op(:foo) ⇒ :foo   # unknown key, passes through
  defp normalize_op(op) when op in @short_ops, do: op_alias(op)
  defp normalize_op(op), do: op

  # ── evaluate/6 ───────────────────────────────────────────────────────
  # The router and normalizer. One clause per public-API meaning. Owns
  # ALL map-form wrapper normalization in this module: every map-form
  # wrapper a caller can express is reduced to tuple IR here before any
  # sub-module is invoked. Sub-modules receive only tuple IR — never a
  # map, never a keyword list of Operand shells, never a binary field
  # name.
  #
  # Returns a dynamic expression or nil. Types.cast is called once per
  # leaf in evaluate_field/6 — after all normalization is complete.

  # Negation lift. Re-enters with negated=:not so the inner shape's
  # clause carries negation forward.
  #
  # evaluate(Post, {:as, nil}, :views, nil, {:not, {:>, 5}}, [])
  #   ⇒ evaluate(Post, {:as, nil}, :views, :not, {:>, 5}, [])
  #   ⇒ dynamic([p], not (p.views > 5))
  defp evaluate(source, binding, key, _negated, {:not, value}, opts) do
    evaluate(source, binding, key, :not, value, opts)
  end

  # Datetime wrapper with map or keyword-list inner — reduce, one dyn per
  # entry. Map and kwlist iterate as {k, v} pairs in Enum.reduce, so a
  # single clause handles both. Non-kwlist lists return nil rather than
  # falling through to the {datetime_op, term} destructure.
  #
  # evaluate(Post, {:as, nil}, :inserted_at, nil,
  #          {:date, %{add: %{days: 7}, before: ~D[2026-01-01]}}, [])
  #   # reduces 2 entries, each re-entering as {:date, {op, term}}:
  #   #   {:date, {:add, %{days: 7}}}
  #   #   {:date, {:before, ~D[2026-01-01]}}
  #   ⇒ dynamic([p],
  #       fragment("? + INTERVAL '7 days'", p.inserted_at) and
  #       p.inserted_at < ~D[2026-01-01])
  #
  # evaluate(Post, {:as, nil}, :inserted_at, nil,
  #          {:date, [add: [days: 7], before: ~D[2026-01-01]]}, [])
  #   # kwlist inner — same reduce, same dispatches
  #   ⇒ dynamic([p],
  #       fragment("? + INTERVAL '7 days'", p.inserted_at) and
  #       p.inserted_at < ~D[2026-01-01])
  #
  # evaluate(Post, {:as, nil}, :inserted_at, nil, {:date, %{}}, [])
  #   ⇒ nil    # empty inner, reduce yields nil
  #
  # evaluate(Post, {:as, nil}, :inserted_at, nil, {:date, [1, 2, 3]}, [])
  #   ⇒ nil    # non-kwlist list, skipped
  defp evaluate(source, binding, key, negated, {wrapper, inner}, opts)
       when wrapper in @datetime_wrappers and
              ((is_map(inner) and not is_struct(inner)) or is_list(inner)) do
    if is_list(inner) and not Keyword.keyword?(inner) do
      nil
    else
      Enum.reduce(inner, nil, fn {datetime_op, term}, acc ->
        dyn = evaluate(source, binding, key, negated, {wrapper, {datetime_op, term}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    end
  end

  # parent_as wrapper with map or keyword-list inner. Each entry
  # {pb, pf} of the inner IS a parent_as reference: key = binding name,
  # value = field name. Multi-entry maps/kwlists fan out as a conjunction.
  #
  # evaluate(Comment, {:as, nil}, :post_id, nil, {:parent_as, %{post: :id}}, [])
  #   ⇒ evaluate_field(... {:parent_as, {:post, :id}})
  #   ⇒ dynamic([c], c.post_id == parent_as(:post).id)
  #
  # evaluate(Comment, {:as, nil}, :post_id, nil, {:parent_as, [post: :id]}, [])
  #   # kwlist inner — same reduce, same dispatch
  #   ⇒ dynamic([c], c.post_id == parent_as(:post).id)
  #
  # evaluate(Comment, {:as, nil}, :post_id, nil, {:parent_as, [1, 2, 3]}, [])
  #   ⇒ nil    # non-kwlist list, skipped
  defp evaluate(source, binding, key, negated, {:parent_as, inner}, opts)
       when (is_map(inner) and not is_struct(inner)) or is_list(inner) do
    if is_list(inner) and not Keyword.keyword?(inner) do
      nil
    else
      Enum.reduce(inner, nil, fn {pb, pf}, acc ->
        dyn = evaluate_field(source, binding, key, negated, {:parent_as, {pb, pf}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    end
  end

  # parent_as wrapper nested under a comparison op. Map or keyword-list
  # inner accepted, same as the bare {:parent_as, inner} clause.
  #
  # evaluate(Comment, {:as, nil}, :views, nil,
  #          {:>, {:parent_as, %{post: :views}}}, [])
  #   ⇒ evaluate_field(... {:>, {:parent_as, {:post, :views}}})
  #   ⇒ dynamic([c], c.views > parent_as(:post).views)
  #
  # evaluate(Comment, {:as, nil}, :views, nil,
  #          {:>, {:parent_as, [post: :views]}}, [])
  #   ⇒ dynamic([c], c.views > parent_as(:post).views)
  defp evaluate(source, binding, key, negated, {op, {:parent_as, inner}}, opts)
       when (is_map(inner) and not is_struct(inner)) or is_list(inner) do
    if is_list(inner) and not Keyword.keyword?(inner) do
      nil
    else
      Enum.reduce(inner, nil, fn {pb, pf}, acc ->
        dyn = evaluate_field(source, binding, key, negated, {op, {:parent_as, {pb, pf}}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    end
  end

  # Operand RHS — comparison op with a map or keyword-list RHS that may
  # be an Operand. Routes to the Operand normalizer when rhs is a
  # single-entry map/kwlist whose key is in @operand_keys; otherwise
  # falls through to a plain literal RHS or kwlist re-entry.
  #
  # evaluate(Post, {:as, nil}, :score, nil,
  #          {:>, %{add: [%{field: :base}, %{value: 5}]}}, [])
  #   ⇒ evaluate_field(... {:>, {:add, [{:field, :base}, {:value, 5}]}})
  #   ⇒ dynamic([p], p.score > p.base + 5)
  #
  # evaluate(Post, {:as, nil}, :score, nil,
  #          {:>, [add: [%{field: :base}, %{value: 5}]]}, [])
  #   # kwlist Operand — same dispatch
  #   ⇒ dynamic([p], p.score > p.base + 5)
  #
  # evaluate(Post, {:as, nil}, :score, nil, {:>, %{add: []}}, [])
  #   # arity violation in normalize_operand → :error
  #   ⇒ nil
  #
  # evaluate(Post, {:as, nil}, :tags, nil, {:==, [1, 2, 3]}, [])
  #   # plain list (not a kwlist) — literal RHS, passed to evaluate_field
  #   ⇒ evaluate_field(... {:==, [1, 2, 3]})
  defp evaluate(source, binding, key, negated, {op, rhs}, opts)
       when op in @comparison_operators and
              ((is_map(rhs) and not is_struct(rhs)) or is_list(rhs)) do
    cond do
      is_list(rhs) and not Keyword.keyword?(rhs) ->
        evaluate_field(source, binding, key, negated, {op, rhs}, opts)

      operand_shape?(rhs) ->
        case normalize_operand(source, rhs, opts) do
          {:ok, tuple_ir} ->
            evaluate_field(source, binding, key, negated, {op, tuple_ir}, opts)

          :error ->
            nil
        end

      is_map(rhs) ->
        evaluate(source, binding, key, negated, {op, Map.to_list(rhs)}, opts)

      true ->
        evaluate_field(source, binding, key, negated, {op, rhs}, opts)
    end
  end

  # Generic map payload — any non-Operand, non-wrapper inner map under
  # any operator. Convert to keyword list and re-enter; downstream
  # clauses never see a map payload.
  #
  # evaluate(Post, {:as, nil}, :score, nil, {:aggregate, %{fn: :avg, compare: :>, value: 50}}, [])
  #   ⇒ evaluate(Post, {:as, nil}, :score, nil,
  #              {:aggregate, [fn: :avg, compare: :>, value: 50]}, [])
  defp evaluate(source, binding, key, negated, {op, params}, opts)
       when is_map(params) and not is_struct(params) do
    evaluate(source, binding, key, negated, {op, Map.to_list(params)}, opts)
  end

  # Common-expression key — the KEY is the operator (e.g. :before,
  # :after, :exists, :since, :until). Hands to evaluate_field/6 unchanged;
  # evaluate_field's first clause routes to CommonExpr.
  #
  # evaluate(Post, {:as, nil}, :before, nil, ~D[2026-01-01], [])
  #   ⇒ evaluate_field(... :before, nil, ~D[2026-01-01], ...)
  #   ⇒ CommonExpr.dynamic_expr({:as, nil}, :before, nil, ~D[2026-01-01], [])
  #   ⇒ dynamic([p], p.inserted_at < ~D[2026-01-01])
  defp evaluate(source, binding, key, negated, value, opts)
       when key in @common_expr_operators do
    evaluate_field(source, binding, key, negated, value, opts)
  end

  # Quantified comparison with list payload. A non-empty kwlist fans out
  # as one dyn per (op, v) pair, AND-merged; otherwise the payload is
  # dispatched whole to evaluate_field/6.
  #
  # evaluate(Post, {:as, nil}, :value, nil, {:any, [eq: 1, gt: 100]}, [])
  #   # kwlist → 2 dispatches:
  #   #   evaluate_field(... {:any, {:==, 1}})
  #   #   evaluate_field(... {:any, {:>, 100}})
  #   ⇒ dynamic([p], p.value == any(...) and p.value > any(...))
  #
  # evaluate(Post, {:as, nil}, :value, nil, {:any, sub_query}, [])
  #   ⇒ evaluate_field(... {:any, sub_query})    # not a kwlist → passed whole
  defp evaluate(source, binding, key, negated, {quantifier, payload}, opts)
       when quantifier in @quantifier_operators and is_list(payload) do
    if Keyword.keyword?(payload) and payload !== [] do
      Enum.reduce(payload, nil, fn {op, v}, acc ->
        canonical_op = if op in @short_ops, do: op_alias(op), else: op
        dyn = evaluate_field(source, binding, key, negated, {quantifier, {canonical_op, v}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    else
      evaluate_field(source, binding, key, negated, {quantifier, payload}, opts)
    end
  end

  # Quantified comparison with non-list payload — single {op, v} tuple
  # or a pre-built Ecto.Query. Canonicalizes short-op aliases inline.
  #
  # evaluate(Post, {:as, nil}, :value, nil, {:any, {:eq, 1}}, [])
  #   ⇒ evaluate_field(... {:any, {:==, 1}})
  #
  # evaluate(Post, {:as, nil}, :value, nil, {:all, %Ecto.SubQuery{}}, [])
  #   ⇒ evaluate_field(... {:all, %Ecto.SubQuery{}})
  defp evaluate(source, binding, key, negated, {quantifier, payload}, opts)
       when quantifier in @quantifier_operators do
    canonical_payload =
      case payload do
        {op, v} when op in @short_ops -> {op_alias(op), v}
        other -> other
      end

    evaluate_field(source, binding, key, negated, {quantifier, canonical_payload}, opts)
  end

  # Transform wrapper. Folds :downcase / :upcase aliases into :lower /
  # :upper and emits {:==, {:lower|:upper, v}}, which ScalarExpr handles
  # via its string-transform family.
  #
  # evaluate(Post, {:as, nil}, :name, nil, {:downcase, "alice"}, [])
  #   ⇒ evaluate_field(... {:==, {:lower, "alice"}})
  #   ⇒ dynamic([p], fragment("LOWER(?)", p.name) == "alice")
  #
  # evaluate(Post, {:as, nil}, :name, nil, {:upcase, "ALICE"}, [])
  #   ⇒ evaluate_field(... {:==, {:upper, "ALICE"}})
  defp evaluate(source, binding, key, negated, {transform, v}, opts)
       when transform in @transform_ops do
    op = if transform in [:lower, :downcase], do: :lower, else: :upper
    evaluate_field(source, binding, key, negated, {:==, {op, v}}, opts)
  end

  # Aggregate shorthand — kwlist payload. agg_fn is one of @agg_fns
  # (:avg, :sum, :max, :min, :count). Each kwlist entry is a
  # {compare_op, value} pair; one dyn per pair, AND-merged.
  #
  # evaluate(Post, {:as, nil}, :score, nil, {:avg, [gt: 50, lt: 100]}, [])
  #   ⇒ AND-merge of:
  #       evaluate_field(... {:avg, {:>, 50}})
  #       evaluate_field(... {:avg, {:<, 100}})
  #   ⇒ dynamic([p], avg(p.score) > 50 and avg(p.score) < 100)
  defp evaluate(source, binding, key, negated, {agg_fn, params}, opts)
       when agg_fn in @agg_fns and is_list(params) do
    if Keyword.keyword?(params) and params !== [] do
      Enum.reduce(params, nil, fn {compare_op, v}, acc ->
        dyn = evaluate_field(source, binding, key, negated, {agg_fn, {compare_op, v}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    else
      evaluate_field(source, binding, key, negated, {agg_fn, params}, opts)
    end
  end

  # Aggregate shorthand — single {compare_op, v} tuple.
  #
  # evaluate(Post, {:as, nil}, :score, nil, {:avg, {:>, 50}}, [])
  #   ⇒ evaluate_field(... {:avg, {:>, 50}})
  #   ⇒ dynamic([p], avg(p.score) > 50)
  defp evaluate(source, binding, key, negated, {agg_fn, {compare_op, v}}, opts)
       when agg_fn in @agg_fns do
    evaluate_field(source, binding, key, negated, {agg_fn, {compare_op, v}}, opts)
  end

  # Aggregate wrapper — explicit %{aggregate: %{fn:, compare:, value:}}
  # shape, normalized to a kwlist by the generic map clause above.
  #
  # evaluate(Post, {:as, nil}, :score, nil,
  #          {:aggregate, [fn: :avg, compare: :>, value: 50]}, [])
  #   ⇒ evaluate_field(... {:avg, {:>, 50}})
  #   ⇒ dynamic([p], avg(p.score) > 50)
  defp evaluate(source, binding, key, negated, {:aggregate, params}, opts)
       when is_list(params) do
    agg_fn = Keyword.fetch!(params, :fn)
    compare_op = Keyword.fetch!(params, :compare)
    value = Keyword.fetch!(params, :value)
    evaluate_field(source, binding, key, negated, {agg_fn, {compare_op, value}}, opts)
  end

  # Elements wrapper — kwlist payload. Forces array routing in
  # evaluate_field/6 regardless of field type. Each kwlist entry re-
  # enters evaluate/6 as {:elements, {op, value}} so every pair gets
  # AND-merged through the same head match.
  #
  # evaluate({"posts", nil}, {:as, nil}, :tags, nil,
  #          {:elements, [in: ["a", "b"], not: %{eq: "c"}]}, [])
  #   ⇒ AND-merge of:
  #       evaluate(... {:elements, {:in, ["a", "b"]}}) → ArrayExpr
  #       evaluate(... {:elements, {:not, %{eq: "c"}}}) → ArrayExpr
  #
  # evaluate({"posts", nil}, {:as, nil}, :tags, nil, {:elements, [1, 2, 3]}, [])
  #   # not a kwlist → equality dispatch
  #   ⇒ evaluate_field(... {:elements, {:==, [1, 2, 3]}})
  defp evaluate(source, binding, key, negated, {:elements, params}, opts)
       when is_list(params) do
    if Keyword.keyword?(params) and params !== [] do
      Enum.reduce(params, nil, fn {op, value}, acc ->
        dyn = evaluate(source, binding, key, negated, {:elements, {op, value}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    else
      evaluate_field(source, binding, key, negated, {:elements, {:==, params}}, opts)
    end
  end

  # Elements wrapper with {op, inner} where inner is a map or kwlist —
  # fan out the inner, one dyn per pair, AND-merged. Non-kwlist lists
  # at this position are unsupported and return nil.
  #
  # evaluate(_, _, :tags, nil, {:elements, {:not, %{eq: "c", in: ["d"]}}}, _)
  #   ⇒ AND-merge of:
  #       evaluate(... {:elements, {:not, {:eq, "c"}}})
  #       evaluate(... {:elements, {:not, {:in, ["d"]}}})
  #
  # evaluate(_, _, :tags, nil, {:elements, {:not, [eq: "c", in: ["d"]]}}, _)
  #   # kwlist inner — same fan-out
  #   ⇒ AND-merge of two dispatches as above
  defp evaluate(source, binding, key, negated, {:elements, {op, inner}}, opts)
       when (is_map(inner) and not is_struct(inner)) or is_list(inner) do
    if is_list(inner) and not Keyword.keyword?(inner) do
      nil
    else
      Enum.reduce(inner, nil, fn {inner_op, v}, acc ->
        dyn = evaluate(source, binding, key, negated, {:elements, {op, {inner_op, v}}}, opts)
        merge_dynamic(acc, :and, dyn)
      end)
    end
  end

  # Elements wrapper with nil payload — equality against nil.
  #
  # evaluate(_, _, :tags, nil, {:elements, nil}, _)
  #   ⇒ evaluate_field(... {:elements, {:==, nil}})
  defp evaluate(source, binding, key, negated, {:elements, nil}, opts) do
    evaluate_field(source, binding, key, negated, {:elements, {:==, nil}}, opts)
  end

  # Elements wrapper with tuple payload.
  #
  # evaluate(_, _, :tags, nil, {:elements, {:in, ["a", "b"]}}, _)
  #   ⇒ evaluate_field(... {:elements, {:in, ["a", "b"]}})
  defp evaluate(source, binding, key, negated, {:elements, {_, _} = term}, opts) do
    evaluate_field(source, binding, key, negated, {:elements, term}, opts)
  end

  # Elements wrapper with bare value — treat as :in operand.
  #
  # evaluate(_, _, :tags, nil, {:elements, "a"}, _)
  #   ⇒ evaluate_field(... {:elements, {:in, "a"}})
  defp evaluate(source, binding, key, negated, {:elements, term}, opts) do
    evaluate_field(source, binding, key, negated, {:elements, {:in, term}}, opts)
  end

  # Plain {op, value} — fully tuple-IR by the time this clause fires.
  # Sub-modules receive only tuple IR.
  #
  # evaluate(Post, {:as, nil}, :views, nil, {:>, 5}, [])
  #   ⇒ evaluate_field(... {:>, 5})
  #   ⇒ dynamic([p], p.views > 5)
  defp evaluate(source, binding, key, negated, {op, v}, opts) do
    evaluate_field(source, binding, key, negated, {op, v}, opts)
  end

  # Bare scalar or non-keyword list — equality.
  #
  # evaluate(Post, {:as, nil}, :views, nil, 5, [])
  #   ⇒ evaluate_field(... {:==, 5})
  #   ⇒ dynamic([p], p.views == 5)
  defp evaluate(source, binding, key, negated, value, opts) do
    evaluate_field(source, binding, key, negated, {:==, value}, opts)
  end

  # ── evaluate_field/6 ─────────────────────────────────────────────────
  # Field-level router. Single Types.cast call site in this module. By
  # the time a term reaches evaluate_field/6, every wrapper has been
  # normalized to tuple IR by evaluate/6. Every sub-module dispatch
  # (CommonExpr, ScalarExpr, ArrayExpr, MapExpr) lives in this function.

  # Common-expr key dispatch. KEY is the operator; value passes through.
  #
  # evaluate_field(Post, {:as, nil}, :before, nil, ~D[2026-01-01], [])
  #   ⇒ CommonExpr.dynamic_expr({:as, nil}, :before, nil, ~D[2026-01-01], [])
  #   ⇒ dynamic([p], p.inserted_at < ~D[2026-01-01])
  defp evaluate_field(_source, binding, key, negated, value, opts)
       when key in @common_expr_operators do
    CommonExpr.dynamic_expr(binding, key, negated, value, opts)
  end

  # Elements-forced array dispatch. The {:elements, …} wrapper is the
  # explicit routing signal carried on the term itself; no opts flag,
  # no hidden state. Array inner-type casting is not performed here;
  # inputs are already tuple IR.
  #
  # evaluate_field(_, {:as, nil}, :tags, nil, {:elements, {:in, ["a", "b"]}}, [])
  #   ⇒ ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:in, ["a", "b"]}, [])
  #   ⇒ dynamic([p], p.tags && ["a", "b"])
  defp evaluate_field(_source, binding, key, negated, {:elements, {_, _} = inner}, opts) do
    ArrayExpr.dynamic_expr(binding, key, negated, inner, opts)
  end

  # Generic field dispatch. Resolves field type, casts the raw value
  # once, and routes to MapExpr / ArrayExpr / ScalarExpr based on type.
  # Schema fields not declared on the schema produce a warning and skip.
  #
  # evaluate_field(Post, {:as, nil}, :views, nil, {:>, 5}, [])
  #   # Post.__schema__(:type, :views) = :integer → ScalarExpr
  #   ⇒ ScalarExpr.dynamic_expr({:as, nil}, :views, nil, {:>, 5}, [])
  #   ⇒ dynamic([p], p.views > 5)
  #
  # evaluate_field(Post, {:as, nil}, :metadata, nil, {:==, %{a: 1}}, [])
  #   # Post.__schema__(:type, :metadata) = :map → MapExpr
  #   ⇒ MapExpr.dynamic_expr({:as, nil}, :metadata, nil, {:==, %{a: 1}}, [])
  #
  # evaluate_field(Post, {:as, nil}, :tags, nil, {:in, ["a"]}, [])
  #   # Post.__schema__(:type, :tags) = {:array, :string} → ArrayExpr
  #   ⇒ ArrayExpr.dynamic_expr({:as, nil}, :tags, nil, {:in, ["a"]}, [])
  #
  # evaluate_field(Post, {:as, nil}, :nope, nil, {:==, 5}, [])
  #   # :nope not in Post.__schema__(:fields)
  #   # logs: Field "nope" does not exist on schema Post, skipping
  #   ⇒ nil
  defp evaluate_field(source, binding, key, negated, {op, raw_value}, opts) do
    field_type = resolve_field_type(source, key, opts)
    value = Types.cast(field_type, raw_value)

    cond do
      invalid_schema_field?(source, key) ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Field \"#{key}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
        )

        nil

      map_field?(field_type) ->
        MapExpr.dynamic_expr(binding, key, negated, {op, value}, opts)

      array_field?(field_type) ->
        ArrayExpr.dynamic_expr(binding, key, negated, {op, value}, opts)

      true ->
        ScalarExpr.dynamic_expr(binding, key, negated, {op, value}, opts)
    end
  end

  # ── resolve_field_type/3 ─────────────────────────────────────────────
  # Resolves the Ecto type of `key`. Caller-supplied opts[:field_types]
  # take precedence over schema reflection — this lets schemaless
  # callers declare types per call.
  #
  # resolve_field_type(Post, :views, [])
  #   ⇒ :integer    # from Post.__schema__(:type, :views)
  #
  # resolve_field_type({"posts", nil}, :tags, field_types: [tags: {:array, :string}])
  #   ⇒ {:array, :string}
  #
  # resolve_field_type({"posts", nil}, :unknown, [])
  #   ⇒ nil
  defp resolve_field_type(source, key, opts) do
    field_types = Keyword.get(opts, :field_types, [])
    Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)
  end

  # ── invalid_schema_field?/2 ──────────────────────────────────────────
  # Predicate: is `key` an atom the source's schema doesn't declare?
  # Returns false when the source has no schema reflection (schemaless).
  #
  # invalid_schema_field?(Post, :views)
  #   ⇒ false       # :views in Post.__schema__(:fields)
  #
  # invalid_schema_field?(Post, :nope)
  #   ⇒ true        # :nope not in Post.__schema__(:fields)
  #
  # invalid_schema_field?({"posts", nil}, :anything)
  #   ⇒ false       # no reflection available, skip the check
  defp invalid_schema_field?(source, key) when is_atom(key) do
    case CommonSchema.get_schema_reflection(source, :fields) do
      fields when is_list(fields) -> key not in fields
      _ -> false
    end
  end

  # ── array_field?/1 / map_field?/1 ────────────────────────────────────
  # Type-shape predicates for evaluate_field/6's cond branches.
  #
  # array_field?({:array, :string})  ⇒ true
  # array_field?({:array, :integer}) ⇒ true
  # array_field?(:integer)           ⇒ false
  # array_field?(:map)               ⇒ false
  # array_field?(nil)                ⇒ false
  #
  # map_field?(:map)         ⇒ true
  # map_field?({:map, :any}) ⇒ true
  # map_field?(:integer)     ⇒ false
  # map_field?(nil)          ⇒ false

  defp array_field?({:array, _}), do: true
  defp array_field?(_), do: false

  defp map_field?(:map), do: true
  defp map_field?({:map, _}), do: true
  defp map_field?(_), do: false

  # NOTE: cast_value/2, build_rhs_entry/4, build_rhs_expr/3,
  # resolve_datetime_wrapper/3, resolve_datetime_node/3, and
  # resolve_elements_value/1 are DELETED. Every wrapper and RHS IR shape
  # they translated is now normalized in evaluate/6 above, producing tuple
  # IR for sub-modules. Sub-modules (ScalarExpr, ArrayExpr, MapExpr) receive
  # fully-normalized tuple IR and do pure pattern-dispatch — no map input,
  # no Map.to_list, no normalize_* helpers, no field-name resolution, no
  # arity validation. This module's sole responsibilities are normalization
  # (the evaluator) and dispatch (evaluate_field/6) — nothing else.

  # ── Operand IR normalization (Change 7) ──────────────────────────────
  # The router walks the Operand tree and converts it to tuple IR.
  # Binary field names are resolved to atoms here. Arity violations emit
  # a warning via arity_warn/3 and return :error; the calling evaluator
  # clause then emits nil so merge_dynamic tolerates the missing dyn.

  # ── operand_shape?/1 ─────────────────────────────────────────────────
  # Predicate: is `m` a single-entry map OR keyword list whose only key
  # is an Operand grammar key (∈ @operand_keys)?
  #
  # operand_shape?(%{add: [%{field: :a}, %{value: 1}]}) ⇒ true
  # operand_shape?([add: [%{field: :a}, %{value: 1}]])  ⇒ true   # kwlist form
  # operand_shape?(%{field: :x})                        ⇒ true
  # operand_shape?([field: :x])                         ⇒ true
  # operand_shape?(%{value: 5})                         ⇒ true
  # operand_shape?(%{abs: %{field: :y}})                ⇒ true
  # operand_shape?(%{add: [], subtract: []})            ⇒ false   # multi-entry map
  # operand_shape?([add: [], subtract: []])             ⇒ false   # multi-entry kwlist
  # operand_shape?(%{not_an_op: 1})                     ⇒ false   # key not in @operand_keys
  # operand_shape?([not_an_op: 1])                      ⇒ false
  # operand_shape?(%{})                                 ⇒ false   # zero-entry
  # operand_shape?([])                                  ⇒ false
  # operand_shape?([1, 2, 3])                           ⇒ false   # non-kwlist list
  # operand_shape?(5)                                   ⇒ false   # not a map or list
  # operand_shape?(%Ecto.Query{})                       ⇒ false   # struct
  defp operand_shape?(m) when (is_map(m) and not is_struct(m)) or is_list(m) do
    entries =
      cond do
        is_map(m) -> Map.to_list(m)
        Keyword.keyword?(m) -> m
        true -> nil
      end

    case entries do
      [{k, _}] -> k in @operand_keys
      _ -> false
    end
  end

  defp operand_shape?(_), do: false

  # ── normalize_operand/3 ──────────────────────────────────────────────
  # Recursive Operand-tree normalizer. Converts a public-API Operand
  # node (map OR single-entry keyword list, OR bare scalar) into tuple
  # IR. Binary field names are resolved to atoms via field_name_to_atom/3.
  # Map and kwlist forms are accepted at every level — operand lists
  # may contain mixed forms (a kwlist inside a map's variadic operand
  # list, etc.) and recursion handles each entry independently.
  #
  # normalize_operand(Post, %{field: :views}, [])
  #   ⇒ {:ok, {:field, :views}}
  #
  # normalize_operand(Post, [field: :views], [])
  #   ⇒ {:ok, {:field, :views}}    # kwlist Operand
  #
  # normalize_operand(Post, %{field: "views"}, [])
  #   ⇒ {:ok, {:field, :views}}    # binary resolved via reflection
  #
  # normalize_operand(Post, %{value: 5}, [])
  #   ⇒ {:ok, {:value, 5}}
  #
  # normalize_operand(Post, %{add: [%{field: :a}, %{value: 1}]}, [])
  #   ⇒ {:ok, {:add, [{:field, :a}, {:value, 1}]}}
  #
  # normalize_operand(Post, [add: [[field: :a], [value: 1]]], [])
  #   # kwlist Operand whose operand list itself contains kwlist Operands
  #   ⇒ {:ok, {:add, [{:field, :a}, {:value, 1}]}}
  #
  # normalize_operand(Post, %{add: [%{field: :a}, 1]}, [])
  #   # bare scalar 1 lifted to {:value, 1}
  #   ⇒ {:ok, {:add, [{:field, :a}, {:value, 1}]}}
  #
  # normalize_operand(Post, %{abs: %{field: :x}}, [])
  #   ⇒ {:ok, {:abs, {:field, :x}}}
  #
  # normalize_operand(Post, %{power: [%{field: :y}, %{value: 2}]}, [])
  #   ⇒ {:ok, {:power, [{:field, :y}, {:value, 2}]}}
  #
  # normalize_operand(Post, 5, [])
  #   ⇒ {:ok, {:value, 5}}    # bare scalar lifted
  #
  # normalize_operand(Post, %{add: [%{field: :a}]}, [])
  #   # warns: Operand `add` requires ≥2 operand(s)
  #   ⇒ :error
  #
  # normalize_operand(Post, %{nope: 1}, [])
  #   # warns: Unrecognized Operand shape: %{nope: 1}
  #   ⇒ :error
  #
  # normalize_operand(Post, [1, 2, 3], [])
  #   # plain list at an Operand position is malformed
  #   # warns: Unrecognized Operand shape: [1, 2, 3]
  #   ⇒ :error
  defp normalize_operand(source, node, opts)
       when (is_map(node) and not is_struct(node)) or is_list(node) do
    entries =
      cond do
        is_map(node) -> Map.to_list(node)
        Keyword.keyword?(node) -> node
        true -> nil
      end

    case entries do
      [{:field, name}] -> normalize_field_leaf(source, name, opts)
      [{:value, v}] -> {:ok, {:value, v}}
      [{op, operands}] when op in @operand_variadic_keys ->
        normalize_variadic(source, op, operands, opts)
      [{op, operands}] when op in @operand_binary_keys ->
        normalize_binary(source, op, operands, opts)
      [{op, operand}] when op in @operand_unary_keys ->
        normalize_unary(source, op, operand, opts)
      _ ->
        warn_unknown_operand(node)
        :error
    end
  end

  # Bare scalar inside an operand list — lift to {:value, v} tuple IR.
  defp normalize_operand(_source, v, _opts) when not is_map(v) and not is_list(v) do
    {:ok, {:value, v}}
  end

  # Anything else (e.g. a struct) is unrecognized.
  defp normalize_operand(_source, node, _opts) do
    warn_unknown_operand(node)
    :error
  end

  # ── normalize_field_leaf/3 ───────────────────────────────────────────
  # Resolves a field reference to {:field, atom}. Binary names are
  # resolved against schema reflection or opts[:allowed_keys] via
  # field_name_to_atom/3.
  #
  # normalize_field_leaf(Post, :views, [])
  #   ⇒ {:ok, {:field, :views}}
  #
  # normalize_field_leaf(Post, "views", [])
  #   ⇒ {:ok, {:field, :views}}     # binary validated against reflection
  #
  # normalize_field_leaf({"posts", nil}, "views", allowed_keys: ["views"])
  #   ⇒ {:ok, {:field, :views}}     # no schema, allowed via :allowed_keys
  #
  # normalize_field_leaf(Post, "no_such_field", [])
  #   # warns: Operand `field` requires valid atom or binary matching a
  #   #        schema field operand(s), got: "no_such_field"
  #   ⇒ :error
  #
  # normalize_field_leaf(Post, nil, [])
  #   ⇒ :error
  defp normalize_field_leaf(source, name, opts) do
    case field_name_to_atom(source, name, opts) do
      atom when is_atom(atom) and atom != nil -> {:ok, {:field, atom}}
      _ ->
        arity_warn(:field, "valid atom or binary matching a schema field", name)
        :error
    end
  end

  # ── normalize_variadic/4 ─────────────────────────────────────────────
  # Validates and normalizes an N-ary arithmetic operand (add, subtract,
  # multiply, divide). Requires ≥ 2 operands.
  #
  # normalize_variadic(Post, :add, [%{field: :a}, %{value: 1}], [])
  #   ⇒ {:ok, {:add, [{:field, :a}, {:value, 1}]}}
  #
  # normalize_variadic(Post, :multiply, [%{field: :a}, %{field: :b}, %{value: 2}], [])
  #   ⇒ {:ok, {:multiply, [{:field, :a}, {:field, :b}, {:value, 2}]}}
  #
  # normalize_variadic(Post, :add, [%{field: :a}], [])
  #   # warns: Operand `add` requires ≥2 operand(s), got: [%{field: :a}]
  #   ⇒ :error
  #
  # normalize_variadic(Post, :add, [], [])
  #   # warns: Operand `add` requires ≥2 operand(s), got: []
  #   ⇒ :error
  #
  # normalize_variadic(Post, :add, "not a list", [])
  #   # warns: Operand `add` requires ≥2 operand(s), got: "not a list"
  #   ⇒ :error
  defp normalize_variadic(source, op, operands, opts)
       when is_list(operands) and length(operands) >= 2 do
    normalize_operand_list(source, op, operands, opts)
  end

  defp normalize_variadic(_source, op, operands, _opts) do
    arity_warn(op, "≥2", operands)
    :error
  end

  # ── normalize_binary/4 ───────────────────────────────────────────────
  # Validates and normalizes a binary arithmetic operand (power, mod).
  # Requires exactly 2 operands.
  #
  # normalize_binary(Post, :power, [%{field: :y}, %{value: 2}], [])
  #   ⇒ {:ok, {:power, [{:field, :y}, {:value, 2}]}}
  #
  # normalize_binary(Post, :mod, [%{field: :a}, 10], [])
  #   ⇒ {:ok, {:mod, [{:field, :a}, {:value, 10}]}}
  #
  # normalize_binary(Post, :power, [%{field: :y}], [])
  #   # warns: Operand `power` requires 2 operand(s), got: [%{field: :y}]
  #   ⇒ :error
  #
  # normalize_binary(Post, :power, [%{field: :y}, %{value: 2}, %{value: 3}], [])
  #   # warns: Operand `power` requires 2 operand(s), got: [...3 elems...]
  #   ⇒ :error
  defp normalize_binary(source, op, [x, y], opts) do
    with {:ok, xi} <- normalize_operand(source, x, opts),
         {:ok, yi} <- normalize_operand(source, y, opts) do
      {:ok, {op, [xi, yi]}}
    end
  end

  defp normalize_binary(_source, op, operands, _opts) do
    arity_warn(op, 2, operands)
    :error
  end

  # ── normalize_unary/4 ────────────────────────────────────────────────
  # Validates and normalizes a unary arithmetic operand (abs, round,
  # floor, ceil, sqrt). Requires exactly 1 operand (NOT a list).
  #
  # normalize_unary(Post, :abs, %{field: :x}, [])
  #   ⇒ {:ok, {:abs, {:field, :x}}}
  #
  # normalize_unary(Post, :sqrt, %{value: 9}, [])
  #   ⇒ {:ok, {:sqrt, {:value, 9}}}
  #
  # normalize_unary(Post, :abs, 5, [])
  #   ⇒ {:ok, {:abs, {:value, 5}}}    # bare scalar lifted by inner normalize_operand
  #
  # normalize_unary(Post, :abs, [1, 2], [])
  #   # warns: Operand `abs` requires 1 operand(s), got: [1, 2]
  #   ⇒ :error
  #
  # normalize_unary(Post, :abs, %{add: [1]}, [])
  #   # inner normalize_operand fails (arity); :error propagates
  #   ⇒ :error
  defp normalize_unary(source, op, operand, opts) when not is_list(operand) do
    case normalize_operand(source, operand, opts) do
      {:ok, inner} -> {:ok, {op, inner}}
      :error -> :error
    end
  end

  defp normalize_unary(_source, op, operand, _opts) do
    arity_warn(op, 1, operand)
    :error
  end

  # ── normalize_operand_list/4 ─────────────────────────────────────────
  # Reduces over a list of operand nodes, normalizing each. Halts on the
  # first :error and propagates :error upward. Preserves operand order.
  #
  # normalize_operand_list(Post, :add, [%{field: :a}, %{value: 1}, 2], [])
  #   ⇒ {:ok, {:add, [{:field, :a}, {:value, 1}, {:value, 2}]}}
  #
  # normalize_operand_list(Post, :add, [%{field: :a}, %{nope: 1}], [])
  #   # second operand fails normalize_operand → halt + propagate
  #   ⇒ :error
  defp normalize_operand_list(source, op, operands, opts) do
    Enum.reduce_while(operands, {:ok, []}, fn operand, {:ok, acc} ->
      case normalize_operand(source, operand, opts) do
        {:ok, tuple} -> {:cont, {:ok, [tuple | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, {op, Enum.reverse(reversed)}}
      :error -> :error
    end
  end

  # ── arity_warn/3 ─────────────────────────────────────────────────────
  # Logs an arity-violation warning and returns :error.
  #
  # arity_warn(:add, "≥2", [%{field: :a}])
  #   # logs: Operand `add` requires ≥2 operand(s), got: [%{field: :a}]; skipping
  #   ⇒ :error
  #
  # arity_warn(:power, 2, [%{field: :a}])
  #   # logs: Operand `power` requires 2 operand(s), got: [%{field: :a}]; skipping
  #   ⇒ :error
  #
  # arity_warn(:abs, 1, [1, 2])
  #   # logs: Operand `abs` requires 1 operand(s), got: [1, 2]; skipping
  #   ⇒ :error
  defp arity_warn(op, required, value) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "Operand `#{op}` requires #{required} operand(s), got: #{inspect(value)}; skipping"
    )

    :error
  end

  # ── warn_unknown_operand/1 ───────────────────────────────────────────
  # Logs a warning for an Operand-shaped map whose key is not in
  # @operand_keys, or whose shape is otherwise unrecognized.
  # Return value is unused; called for its side effect.
  #
  # warn_unknown_operand(%{nope: 1})
  #   # logs: Unrecognized Operand shape: %{nope: 1}; skipping
  #   ⇒ :ok    # (Logger.warning return value)
  #
  # warn_unknown_operand(%{add: [], subtract: []})
  #   # logs: Unrecognized Operand shape: %{add: [], subtract: []}; skipping
  #   ⇒ :ok
  defp warn_unknown_operand(node) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "Unrecognized Operand shape: #{inspect(node)}; skipping"
    )
  end

  # ── op_alias/1 ───────────────────────────────────────────────────────
  # Short-op atom → canonical operator atom. Called only by
  # normalize_op/1 and the quantified-comparison clauses in evaluate/6.
  #
  # op_alias(:eq)  ⇒ :==
  # op_alias(:ne)  ⇒ :!=
  # op_alias(:gt)  ⇒ :>
  # op_alias(:gte) ⇒ :>=
  # op_alias(:lt)  ⇒ :<
  # op_alias(:lte) ⇒ :<=
  # op_alias(:foo) ⇒ FunctionClauseError    # caller must guard with `op in @short_ops`
  defp op_alias(:eq), do: :==
  defp op_alias(:ne), do: :!=
  defp op_alias(:gt), do: :>
  defp op_alias(:gte), do: :>=
  defp op_alias(:lt), do: :<
  defp op_alias(:lte), do: :<=

  # ── field_name_to_atom/3 ─────────────────────────────────────────────
  # Resolves a field name to an existing atom. Atoms pass through
  # unchanged; binaries are validated against schema reflection or
  # opts[:allowed_keys]. Called only by normalize_field_leaf/3.
  # Sub-modules never call this; they receive atoms in tuple IR.
  #
  # field_name_to_atom(Post, :views, [])
  #   ⇒ :views                       # atom passes through
  #
  # field_name_to_atom(Post, "views", [])
  #   ⇒ :views                       # binary, found in Post.__schema__(:fields)
  #
  # field_name_to_atom(Post, "nope", [])
  #   # logs: Field "nope" does not exist on schema Post, skipping field reference
  #   ⇒ nil
  #
  # field_name_to_atom({"posts", nil}, "views", allowed_keys: ["views"])
  #   ⇒ :views                       # no schema, allowed via opts
  #
  # field_name_to_atom({"posts", nil}, "views", allowed_keys: ["title"])
  #   # logs: Field "views" is not in the :allowed_keys list, skipping field reference
  #   ⇒ nil
  #
  # field_name_to_atom({"posts", nil}, "views", [])
  #   # logs: Field "views" cannot be resolved: no schema or :allowed_keys available
  #   ⇒ nil
  defp field_name_to_atom(_source, field_name, _opts) when is_atom(field_name), do: field_name

  defp field_name_to_atom(source, field_name, opts) when is_binary(field_name) do
    # unchanged — see current implementation
  end

  # ── merge_dynamic/3 ──────────────────────────────────────────────────
  # AND/OR merger for dynamic expressions. Tolerates nil on either side
  # so reducers can start from nil and pass through a missing dyn.
  #
  # # given dyn1 = dynamic([p], p.views > 5)
  # #       dyn2 = dynamic([p], p.views < 100)
  #
  # merge_dynamic(nil, :and, dyn1)
  #   ⇒ dyn1                                        # nil left side passes through
  #
  # merge_dynamic(dyn1, :and, nil)
  #   ⇒ dyn1                                        # nil right side passes through
  #
  # merge_dynamic(nil, :and, nil)
  #   ⇒ nil                                         # both nil → nil
  #
  # merge_dynamic(dyn1, :and, dyn2)
  #   ⇒ dynamic([p], p.views > 5 and p.views < 100)
  #
  # merge_dynamic(dyn1, :or, dyn2)
  #   ⇒ dynamic([p], p.views > 5 or p.views < 100)
  defp merge_dynamic(nil, _, b), do: b
  defp merge_dynamic(a, _, nil), do: a
  defp merge_dynamic(a, :and, b), do: dynamic(^a and ^b)
  defp merge_dynamic(a, :or, b), do: dynamic(^a or ^b)
end
```

---

## Projected final state of `lib/ecto_shorts/common_filters.ex`

### Changes

| Line region | Change |
|---|---|
| 229 (alias block) | Add `alias EctoShorts.CommonFilters.Select` |
| 455–456 (`apply_filter/6` fallback) | Resolve subquery spec via `resolve_quantifier_subquery/3` before dispatching to `Builder` |
| Bottom of module | Append 5 private function heads: `resolve_quantifier_subquery/3`, `subquery_spec?/1`, `build_quantified_subquery/3` |

### Final state

```elixir
defmodule EctoShorts.CommonFilters do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Converts public filter params into an `Ecto.Query`.

  (… docstring unchanged from the current file — lines 3–223 …)
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.Config

  alias EctoShorts.CommonFilters.Builder
  alias EctoShorts.CommonFilters.Select    # ← new

  @logger_prefix "EctoShorts.CommonFilters"

  # (… @type filters, @filters, filters/0 — unchanged, lines 233–308 …)

  # ------------------------------------------------------------------------
  # IMPLEMENTATION CONTRACT  (unchanged — lines 310–338)
  # ------------------------------------------------------------------------

  # (… @doc / @spec for convert_params_to_filter/3 unchanged — lines 340–379 …)
  def convert_params_to_filter(source, params, opts \\ []) do
    query = CommonSchema.to_query(source)

    sorted =
      case opts[:sorter] do
        nil -> sort_filter_params(params)
        sorter -> sorter.(params)
      end

    reduce_filters(:where, source, query, {:as, nil}, sorted, opts)
  end

  defp reduce_filters(filter, source, query, selected_binding, params, opts) do
    Enum.reduce(params, query, &apply_filter(filter, source, &2, selected_binding, &1, opts))
  end

  defp apply_filter(filter, source, query, selected_binding, {key, params}, opts) do
    cond do
      key in [:as, :at] ->
        Enum.reduce(params, query, fn {next_key, next_value}, query_acc ->
          case resolve_binding_selector(query_acc, key, next_key) do
            :error ->
              query_acc

            {:ok, resolved} ->
              apply_filter(
                filter,
                source,
                query_acc,
                resolved,
                next_value,
                opts
              )
          end
        end)

      key in [:having, :or_having, :where, :or_where] ->
        cond do
          list_of_params?(params) ->
            reduce_filters(key, source, query, selected_binding, params, opts)

          params?(params) ->
            reduce_filters(key, source, query, selected_binding, params, opts)

          true ->
            Builder.build_query(key, source, query, selected_binding, params, opts)
        end

      assoc_key?(source, key) ->
        if params?(params) do
          apply_assoc_filters(filter, source, query, key, params, opts)
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Expected association filter value to be a map or keyword list, got: #{inspect(params)}"
          )

          query
        end

      key === :and ->
        reduce_filters(filter, source, query, selected_binding, params, opts)

      key === :or ->
        if list_of_params?(params) do
          reduce_filters(:or_where, source, query, selected_binding, params, opts)
        else
          Enum.reduce(params, query, fn {inner_key, inner_value}, query_acc ->
            or_entries(source, query_acc, selected_binding, inner_key, inner_value, opts)
          end)
        end

      key in @filters ->
        Builder.build_query(key, source, query, selected_binding, params, opts)

      # ← CHANGED: resolve any subquery spec before dispatching.
      true ->
        resolved = resolve_quantifier_subquery(key, params, opts)
        Builder.build_query(filter, source, query, selected_binding, {key, resolved}, opts)
    end
  end

  defp apply_filter(filter, source, query, selected_binding, params, opts) do
    reduce_filters(filter, source, query, selected_binding, params, opts)
  end

  defp or_entries(source, query, selected_binding, key, value, opts) do
    Builder.build_query(:or_where, source, query, selected_binding, {key, value}, opts)
  end

  defp apply_assoc_filters(filter, source, query, key, params, opts) do
    assoc_source = get_assoc_source(source, key)

    query_acc =
      Builder.build_query(
        :join,
        source,
        query,
        {:as, nil},
        [association: [source: key, as: key]],
        opts
      )

    apply_filter(filter, assoc_source, query_acc, {:as, key}, params, opts)
  end

  defp resolve_binding_selector(_query, :at, :first) do
    {:ok, {:at, 1}}
  end

  defp resolve_binding_selector(query, :at, :last) do
    {:ok, {:at, CommonQuery.query_binding_count(query)}}
  end

  defp resolve_binding_selector(_query, :at, position) when is_integer(position) do
    max = Config.max_positional_bindings() || 10

    if position >= 1 and position <= max do
      {:ok, {:at, position}}
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Positional binding :at position #{position} is out of range " <>
          "(compiled max: #{max}). Filter skipped."
      )

      :error
    end
  end

  defp resolve_binding_selector(_query, key, inner_key) do
    {:ok, {key, inner_key}}
  end

  defp get_assoc_source(source, key) do
    %{queryable: queryable} = CommonSchema.get_schema_reflection(source, :association, key)
    queryable
  end

  defp assoc_key?(source, key) do
    key in (CommonSchema.get_schema_reflection(source, :associations) || [])
  end

  defp params?(term), do: (is_map(term) and not is_struct(term)) or Keyword.keyword?(term)
  defp list_of_params?([]), do: true
  defp list_of_params?([head | _]), do: params?(head)
  defp list_of_params?(_), do: false

  defp sort_filter_params(params) do
    where_filters = Enum.filter(params, fn {key, _val} -> key === :where end)
    or_where_filters = Enum.filter(params, fn {key, _val} -> key === :or_where end)
    terminal_filters = Enum.filter(params, fn {key, _val} -> key in [:last, :subquery] end)

    other_filters =
      Enum.filter(params, fn {key, _val} -> key not in [:where, :or_where, :last, :subquery] end)

    where_filters
    |> Kernel.++(other_filters)
    |> Kernel.++(or_where_filters)
    |> Kernel.++(terminal_filters)
  end

  # ── New helpers appended at the bottom (Change 2) ────────────────────────

  # ── resolve_quantifier_subquery/3 ────────────────────────────────────
  # Detects an `:all` / `:any` payload that carries a subquery spec
  # (any term matching subquery_spec?/1) and replaces the spec with the
  # built `Ecto.Query`. Non-spec payloads pass through unchanged. Used
  # in apply_filter/6's fallback branch right before Builder dispatch.
  #
  # # given a spec %{from: Comment, post_id: 1} — has :from → spec
  # resolve_quantifier_subquery(:id,
  #   {:any, %{from: Comment, post_id: 1}}, [])
  #   ⇒ {:any, %Ecto.Query{from: Comment, ...}}    # spec built
  #
  # resolve_quantifier_subquery(:id,
  #   {:>, {:all, [from: Comment, views: 100]}}, [])
  #   ⇒ {:>, {:all, %Ecto.Query{from: Comment, ...}}}
  #
  # resolve_quantifier_subquery(:id, {:any, [1, 2, 3]}, [])
  #   ⇒ {:any, [1, 2, 3]}                          # not a spec, passes through
  #
  # resolve_quantifier_subquery(:id, {:>, 5}, [])
  #   ⇒ {:>, 5}                                    # no quantifier, passes through
  defp resolve_quantifier_subquery(key, {quantifier, payload}, opts)
       when quantifier in [:all, :any] do
    if subquery_spec?(payload),
      do: {quantifier, build_quantified_subquery(key, payload, opts)},
      else: {quantifier, payload}
  end

  defp resolve_quantifier_subquery(key, {op, {quantifier, payload}}, opts)
       when quantifier in [:all, :any] do
    if subquery_spec?(payload),
      do: {op, {quantifier, build_quantified_subquery(key, payload, opts)}},
      else: {op, {quantifier, payload}}
  end

  defp resolve_quantifier_subquery(_key, params, _opts), do: params

  # ── subquery_spec?/1 ─────────────────────────────────────────────────
  # Predicate: does `payload` carry a `:from` key, marking it as a
  # subquery specification? Maps and keyword lists may both qualify.
  #
  # subquery_spec?(%{from: Comment, post_id: 1})       ⇒ true
  # subquery_spec?([from: Comment, post_id: 1])        ⇒ true
  # subquery_spec?(%{post_id: 1})                      ⇒ false   # no :from
  # subquery_spec?([post_id: 1])                       ⇒ false   # no :from
  # subquery_spec?([1, 2, 3])                          ⇒ false   # not a kwlist
  # subquery_spec?(%Ecto.Query{})                      ⇒ false   # struct, not a spec
  # subquery_spec?(5)                                  ⇒ false
  defp subquery_spec?(payload) when is_map(payload) and not is_struct(payload),
    do: Map.has_key?(payload, :from)

  defp subquery_spec?(payload) when is_list(payload),
    do: Keyword.keyword?(payload) and Keyword.has_key?(payload, :from)

  defp subquery_spec?(_payload), do: false

  # ── build_quantified_subquery/3 ──────────────────────────────────────
  # Materializes a subquery-spec map or keyword list into an Ecto.Query
  # by recursing through `convert_params_to_filter/3` for the where part
  # and projecting the chosen `:select` field via `Select.build_query/6`.
  #
  # The outer field key (the LHS of the comparison this subquery is
  # being compared against) is the default `:select` projection when
  # the spec doesn't specify one.
  #
  # # given a Comment schema with fields [:post_id, :views, ...]
  #
  # build_quantified_subquery(:id,
  #   %{from: Comment, post_id: 1}, [])
  #   ⇒ %Ecto.Query{from: Comment, where: [post_id == 1], select: c.id}
  #   # outer_key :id used as default select
  #
  # build_quantified_subquery(:id,
  #   [from: Comment, select: :post_id, post_id: 1], [])
  #   ⇒ %Ecto.Query{from: Comment, where: [post_id == 1], select: c.post_id}
  #
  # build_quantified_subquery(:id,
  #   [from: Comment, select: "post_id", post_id: 1], [])
  #   # binary "post_id" matched against Comment.__schema__(:fields)
  #   ⇒ %Ecto.Query{from: Comment, ..., select: c.post_id}
  #
  # build_quantified_subquery(:id,
  #   [from: Comment, select: %{field: :post_id}, post_id: 1], [])
  #   ⇒ %Ecto.Query{from: Comment, ..., select: c.post_id}
  #
  # build_quantified_subquery(:id, %{from: Comment}, [])
  #   ⇒ %Ecto.Query{from: Comment, select: c.id}    # no where, falls through to outer_key
  #
  # build_quantified_subquery(:id, "not a map or kwlist", [])
  #   # logs: Expected a map or keyword list, got: "not a map or kwlist"
  #   ⇒ "not a map or kwlist"     # original term returned
  defp build_quantified_subquery(outer_key, params, opts)
       when is_map(params) and not is_struct(params) do
    build_quantified_subquery(outer_key, Map.to_list(params), opts)
  end

  defp build_quantified_subquery(outer_key, params, opts) do
    if Keyword.keyword?(params) do
      {source, params_without_from} = Keyword.pop(params, :from, [])
      {select_spec, where_params} = Keyword.pop(params_without_from, :select)

      select_term =
        case select_spec || outer_key do
          field when is_atom(field) and field !== nil ->
            field

          field when is_binary(field) ->
            fields = CommonSchema.get_schema_reflection(source, :fields) || []
            Enum.find(fields, &(Atom.to_string(&1) == field)) || outer_key

          params ->
            if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
              field_atom = params[:field]
              if is_atom(field_atom) and field_atom != nil, do: field_atom, else: outer_key
            else
              outer_key
            end
        end

      inner_query = convert_params_to_filter(source, where_params, opts)
      Select.build_query(:select, source, inner_query, {:as, nil}, select_term, opts)
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Expected a map or keyword list, got: #{inspect(params)}"
      )

      params
    end
  end
end
```

---

## Projected final state of `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex`

### Changes

| Region | Lines in current file | Change |
|---|---|---|
| `family_for/2` | 799–820 | Add one clause that detects tuple-IR Operand RHS and routes to a new `:arithmetic` family |
| `comparison_impl/4` — arithmetic + `:value` wrapper clauses | 571–593 | Delete the legacy `{op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}}` clause and its negated twin (the old `:arithmetic` wrapper shape is gone). The bare `{op_v, {:value, v}}` clauses stay — they are already tuple IR and remain the canonical scalar literal dispatch. |
| `apply_arith_comparison/6` | 681–728 | Delete all 48 clauses — replaced by tuple-IR dispatch |
| New section at bottom | — | Add `arithmetic_impl/4` plus `build_operand_dyn/2` — a pure recursive tuple-to-SQL emitter. No IR translation, no field-name resolution, no arity validation (all done in the router before the tuple arrives). |

### Final state

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.QueryBinding

  import Ecto.Query

  @aggregate_helpers [:avg, :count, :max, :min, :sum]
  @operators [:membership, :comparison, :string_transform, :string]
  @comparison_operators [:>, :>=, :<, :<=, :==, :!=]
  @equality_operators [:==, :!=]
  @string_operators [:like, :ilike]

  @operand_keys [
    :field,
    :value,
    :add,
    :subtract,
    :multiply,
    :divide,
    :power,
    :mod,
    :abs,
    :round,
    :floor,
    :ceil,
    :sqrt
  ]

  context = __MODULE__
  key_var = Macro.var(:key, context)

  def operators, do: @operators

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    # Thin entry shim - delegates entirely to non-generated dispatch_expr
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      dispatch_expr(selected_binding, key, negated, term)
    end

    # Binding-specific field accessor functions (one dynamic/2 call each, no logic)
    defp field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^unquote(key_var))
      )
    end

    defp nil_field_dyn?(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp not_nil_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        not is_nil(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp date_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("date(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp lower_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("lower(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp upper_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("upper(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp avg_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        avg(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp count_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        count(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp max_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        max(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp min_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        min(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp sum_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        sum(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp membership_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^unquote(key_var)) in ^values
      )
    end

    defp membership_not_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^unquote(key_var))) or
          field(unquote(target_binding_var), ^unquote(key_var)) not in ^values
      )
    end

    defp membership_nil_aware_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        not is_nil(field(unquote(target_binding_var), ^unquote(key_var))) and
          field(unquote(target_binding_var), ^unquote(key_var)) in ^values
      )
    end
  end

  # ── Non-generated dispatch: compiled once regardless of binding count ──────

  defp dispatch_expr(binding, key, negated, {op, value}) do
    case family_for(op, value) do
      :membership -> membership_impl(binding, key, negated, {op, value})
      :string_transform -> string_transform_impl(binding, key, negated, {op, value})
      :string -> string_impl(binding, key, negated, {op, value})
      :arithmetic -> arithmetic_impl(binding, key, negated, {op, value})
      :comparison -> comparison_impl(binding, key, negated, {op, value})
    end
  end

  defp membership_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:in, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:in, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:not, {:==, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:==, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:not, {:!=, values}} when is_list(values) ->
        membership_nil_aware_in_dyn(binding, key, values)

      {:!=, values} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      _ ->
        nil
    end
  end

  defp string_transform_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:==, {:lower, v}}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:==, {:lower, v}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:!=, {:lower, v}}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:!=, {:lower, v}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:not, {:==, {:upper, v}}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:==, {:upper, v}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:!=, {:upper, v}}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:!=, {:upper, v}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      _ ->
        nil
    end
  end

  defp string_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:like, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], not fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:like, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:not, {:ilike, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], not fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:ilike, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:not, {:like, v}} ->
        f = field_dyn(binding, key)
        dynamic([], not like(^f, ^preserve_or_wrap_pattern(v)))

      {:like, v} ->
        f = field_dyn(binding, key)
        dynamic([], like(^f, ^preserve_or_wrap_pattern(v)))

      {:not, {:ilike, v}} ->
        f = field_dyn(binding, key)
        dynamic([], not ilike(^f, ^preserve_or_wrap_pattern(v)))

      {:ilike, v} ->
        f = field_dyn(binding, key)
        dynamic([], ilike(^f, ^preserve_or_wrap_pattern(v)))
    end
  end

  # All comparison cases in one function - compiled once, not 12×
  defp comparison_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      # Nil checks
      {:==, nil} ->
        nil_field_dyn?(binding, key)

      {:not, {:==, nil}} ->
        not_nil_dyn(binding, key)

      {:!=, nil} ->
        not_nil_dyn(binding, key)

      {:not, {:!=, nil}} ->
        nil_field_dyn?(binding, key)

      # Scalar comparisons
      {:==, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:==, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:!=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:not, {:!=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:>, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f > ^v)

      {:not, {:>, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > ^v))

      {:>=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= ^v)

      {:not, {:>=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= ^v))

      {:<, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f < ^v)

      {:not, {:<, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < ^v))

      {:<=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= ^v)

      {:not, {:<=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= ^v))

      # Quantified comparisons (all / any)
      {:==, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == all(qv))

      {:not, {:==, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f == all(qv)))

      {:==, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == any(qv))

      {:not, {:==, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f == any(qv)))

      {:!=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != all(qv))

      {:not, {:!=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f != all(qv)))

      {:!=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != any(qv))

      {:not, {:!=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f != any(qv)))

      {:>, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f > all(qv))

      {:not, {:>, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > all(qv)))

      {:>, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f > any(qv))

      {:not, {:>, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > any(qv)))

      {:>=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= all(qv))

      {:not, {:>=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= all(qv)))

      {:>=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= any(qv))

      {:not, {:>=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= any(qv)))

      {:<, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f < all(qv))

      {:not, {:<, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < all(qv)))

      {:<, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f < any(qv))

      {:not, {:<, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < any(qv)))

      {:<=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= all(qv))

      {:not, {:<=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= all(qv)))

      {:<=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= any(qv))

      {:not, {:<=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= any(qv)))

      # Aggregate: nil checks
      {helper, {:==, nil}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], is_nil(^f))

      {:not, {helper, {:==, nil}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not is_nil(^f))

      {helper, {:!=, nil}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not is_nil(^f))

      {:not, {helper, {:!=, nil}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], is_nil(^f))

      # Aggregate: value comparisons
      {helper, {:==, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f == ^v)

      {:not, {helper, {:==, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f != ^v)

      {helper, {:!=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f != ^v)

      {:not, {helper, {:!=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f == ^v)

      {helper, {:>, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f > ^v)

      {:not, {helper, {:>, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f > ^v))

      {helper, {:>=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f >= ^v)

      {:not, {helper, {:>=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f >= ^v))

      {helper, {:<, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f < ^v)

      {:not, {helper, {:<, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f < ^v))

      {helper, {:<=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f <= ^v)

      {:not, {helper, {:<=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f <= ^v))

      # Datetime comparisons - interval is already a ^-pinned runtime var after Phase 1
      {:==, {:date, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f == fragment("date(?)", ago(^count, ^interval)))

      {:!=, {:date, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f != fragment("date(?)", from_now(^count, ^interval)))

      {:not, {:>, {:date, {:from_now, params}}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], not (^f > fragment("date(?)", from_now(^count, ^interval))))

      {:>=, {:date, {:add, params}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], ^f >= fragment("date(?)", datetime_add(^f2, ^count, ^interval)))

      {:>=, {:datetime, {:add, params}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], ^f >= datetime_add(^f2, ^count, ^interval))

      {:not, {:>=, {:datetime, {:add, params}}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], not (^f >= datetime_add(^f2, ^count, ^interval)))

      {:>, {:datetime, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f > ago(^count, ^interval))

      {:>, {:datetime, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f > from_now(^count, ^interval))

      {:not, {:<, {:datetime, {:ago, params}}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], not (^f < ago(^count, ^interval)))

      {:<, {:datetime, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f < ago(^count, ^interval))

      {:<=, {:datetime, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f <= from_now(^count, ^interval))

      {:<, {:date, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f < fragment("date(?)", ago(^count, ^interval)))

      # Generic datetime - all ops × {datetime,date} × {ago,from_now,add}
      {op_d, {wrapper, {datetime_op, params}}}
      when op_d in @comparison_operators and wrapper in [:datetime, :date] and
             datetime_op in [:ago, :from_now, :add] ->
        apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :plain)

      {:not, {op_d, {wrapper, {datetime_op, params}}}}
      when op_d in @comparison_operators and wrapper in [:datetime, :date] and
             datetime_op in [:ago, :from_now, :add] ->
        apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :negated)


      # Value wrapper (unwraps plain scalar/field references)
      {:not, {op_v, {:value, v}}} when op_v in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_v, f, v, :negated)

      {op_v, {:value, v}} when op_v in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_v, f, v, :plain)

      # parent_as: compare current binding field against a field on a named parent binding
      {:parent_as, {pb, pf}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == field(parent_as(^pb), ^pf))

      {:not, {:parent_as, {pb, pf}}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != field(parent_as(^pb), ^pf))

      {op_g, {:parent_as, {pb, pf}}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_parent_as_comparison(op_g, f, pb, pf, :plain)

      {:not, {op_g, {:parent_as, {pb, pf}}}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_parent_as_comparison(op_g, f, pb, pf, :negated)

      # Generic scalar fallback (catches any remaining value)
      {:not, {op_g, v}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_g, f, v, :negated)

      {op_g, v} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_g, f, v, :plain)

      _ ->
        nil
    end
  end

  defp agg_field_dyn(binding, key, :avg), do: avg_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :count), do: count_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :max), do: max_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :min), do: min_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :sum), do: sum_field_dyn(binding, key)

  defp apply_scalar_comparison(:==, f, v, :plain), do: dynamic([], ^f == ^v)
  defp apply_scalar_comparison(:==, f, v, :negated), do: dynamic([], ^f != ^v)
  defp apply_scalar_comparison(:!=, f, v, :plain), do: dynamic([], ^f != ^v)
  defp apply_scalar_comparison(:!=, f, v, :negated), do: dynamic([], ^f == ^v)
  defp apply_scalar_comparison(:>, f, v, :plain), do: dynamic([], ^f > ^v)
  defp apply_scalar_comparison(:>, f, v, :negated), do: dynamic([], not (^f > ^v))
  defp apply_scalar_comparison(:>=, f, v, :plain), do: dynamic([], ^f >= ^v)
  defp apply_scalar_comparison(:>=, f, v, :negated), do: dynamic([], not (^f >= ^v))
  defp apply_scalar_comparison(:<, f, v, :plain), do: dynamic([], ^f < ^v)
  defp apply_scalar_comparison(:<, f, v, :negated), do: dynamic([], not (^f < ^v))
  defp apply_scalar_comparison(:<=, f, v, :plain), do: dynamic([], ^f <= ^v)
  defp apply_scalar_comparison(:<=, f, v, :negated), do: dynamic([], not (^f <= ^v))

  defp apply_parent_as_comparison(:==, f, pb, pf, :plain),
    do: dynamic([], ^f == field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:==, f, pb, pf, :negated),
    do: dynamic([], ^f != field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:!=, f, pb, pf, :plain),
    do: dynamic([], ^f != field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:!=, f, pb, pf, :negated),
    do: dynamic([], ^f == field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>, f, pb, pf, :plain),
    do: dynamic([], ^f > field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>, f, pb, pf, :negated),
    do: dynamic([], not (^f > field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:>=, f, pb, pf, :plain),
    do: dynamic([], ^f >= field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>=, f, pb, pf, :negated),
    do: dynamic([], not (^f >= field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:<, f, pb, pf, :plain),
    do: dynamic([], ^f < field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:<, f, pb, pf, :negated),
    do: dynamic([], not (^f < field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:<=, f, pb, pf, :plain),
    do: dynamic([], ^f <= field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:<=, f, pb, pf, :negated),
    do: dynamic([], not (^f <= field(parent_as(^pb), ^pf)))


  defp apply_datetime_comparison(binding, key, op, :datetime, :ago, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], ago(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :from_now, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], from_now(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :add, params, mode) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    rhs = dynamic([], datetime_add(^f2, ^count, ^interval))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :ago, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    rhs = dynamic([], fragment("date(?)", ago(^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :from_now, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    rhs = dynamic([], fragment("date(?)", from_now(^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :add, params, mode) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    rhs = dynamic([], fragment("date(?)", datetime_add(^f2, ^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end
  defp arithmetic_impl(binding, key, negated, {op, operand_tuple}) do
    lhs = field_dyn(binding, key)

    case build_operand_dyn(binding, operand_tuple) do
      nil ->
        nil

      rhs_dyn ->
        mode = if negated === :not, do: :negated, else: :plain
        apply_dyn_comparison(op, lhs, rhs_dyn, mode)
    end
  end

  defp build_operand_dyn(binding, {:field, atom}) when is_atom(atom) do
    field_dyn(binding, atom)
  end

  defp build_operand_dyn(_binding, {:value, v}) do
    dynamic([], ^v)
  end

  defp build_operand_dyn(binding, {:add, operands}) when is_list(operands) do
    fold_variadic(binding, operands, fn a, b -> dynamic([], ^a + ^b) end)
  end

  defp build_operand_dyn(binding, {:subtract, operands}) when is_list(operands) do
    fold_variadic(binding, operands, fn a, b -> dynamic([], ^a - ^b) end)
  end

  defp build_operand_dyn(binding, {:multiply, operands}) when is_list(operands) do
    fold_variadic(binding, operands, fn a, b -> dynamic([], ^a * ^b) end)
  end

  defp build_operand_dyn(binding, {:divide, operands}) when is_list(operands) do
    fold_variadic(binding, operands, fn a, b -> dynamic([], ^a / ^b) end)
  end

  defp build_operand_dyn(binding, {:power, [x, y]}) do
    with xd when xd != nil <- build_operand_dyn(binding, x),
         yd when yd != nil <- build_operand_dyn(binding, y) do
      dynamic([], fragment("POWER(?, ?)", ^xd, ^yd))
    end
  end

  defp build_operand_dyn(binding, {:mod, [x, y]}) do
    with xd when xd != nil <- build_operand_dyn(binding, x),
         yd when yd != nil <- build_operand_dyn(binding, y) do
      dynamic([], fragment("MOD(?, ?)", ^xd, ^yd))
    end
  end

  defp build_operand_dyn(binding, {:abs, inner}) do
    case build_operand_dyn(binding, inner) do
      nil -> nil
      dyn -> dynamic([], fragment("ABS(?)", ^dyn))
    end
  end

  defp build_operand_dyn(binding, {:round, inner}) do
    case build_operand_dyn(binding, inner) do
      nil -> nil
      dyn -> dynamic([], fragment("ROUND(?)", ^dyn))
    end
  end

  defp build_operand_dyn(binding, {:floor, inner}) do
    case build_operand_dyn(binding, inner) do
      nil -> nil
      dyn -> dynamic([], fragment("FLOOR(?)", ^dyn))
    end
  end

  defp build_operand_dyn(binding, {:ceil, inner}) do
    case build_operand_dyn(binding, inner) do
      nil -> nil
      dyn -> dynamic([], fragment("CEIL(?)", ^dyn))
    end
  end

  defp build_operand_dyn(binding, {:sqrt, inner}) do
    case build_operand_dyn(binding, inner) do
      nil -> nil
      dyn -> dynamic([], fragment("SQRT(?)", ^dyn))
    end
  end

  defp build_operand_dyn(_binding, _other), do: nil

  defp fold_variadic(binding, operands, combiner) do
    Enum.reduce(operands, nil, fn operand, acc ->
      case build_operand_dyn(binding, operand) do
        nil -> acc
        dyn when acc === nil -> dyn
        dyn -> combiner.(acc, dyn)
      end
    end)
  end


  defp apply_dyn_comparison(:==, lhs, rhs, :plain), do: dynamic([], ^lhs == ^rhs)
  defp apply_dyn_comparison(:==, lhs, rhs, :negated), do: dynamic([], ^lhs != ^rhs)
  defp apply_dyn_comparison(:!=, lhs, rhs, :plain), do: dynamic([], ^lhs != ^rhs)
  defp apply_dyn_comparison(:!=, lhs, rhs, :negated), do: dynamic([], ^lhs == ^rhs)
  defp apply_dyn_comparison(:>, lhs, rhs, :plain), do: dynamic([], ^lhs > ^rhs)
  defp apply_dyn_comparison(:>, lhs, rhs, :negated), do: dynamic([], not (^lhs > ^rhs))
  defp apply_dyn_comparison(:>=, lhs, rhs, :plain), do: dynamic([], ^lhs >= ^rhs)
  defp apply_dyn_comparison(:>=, lhs, rhs, :negated), do: dynamic([], not (^lhs >= ^rhs))
  defp apply_dyn_comparison(:<, lhs, rhs, :plain), do: dynamic([], ^lhs < ^rhs)
  defp apply_dyn_comparison(:<, lhs, rhs, :negated), do: dynamic([], not (^lhs < ^rhs))
  defp apply_dyn_comparison(:<=, lhs, rhs, :plain), do: dynamic([], ^lhs <= ^rhs)
  defp apply_dyn_comparison(:<=, lhs, rhs, :negated), do: dynamic([], not (^lhs <= ^rhs))

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  defp family_for(:in, _term), do: :membership

  defp family_for(op, value) when op in @equality_operators and is_list(value) do
    :membership
  end

  defp family_for(op, {transform, _term})
       when op in @comparison_operators and transform in [:lower, :upper] do
    :string_transform
  end

  defp family_for(op, term) when op in @string_operators do
    case term do
      {transform, _term} when transform in [:lower, :upper] ->
        :string_transform

      _ ->
        :string
    end
  end
  defp family_for(op, {operand_key, _})
       when op in @comparison_operators and operand_key in @operand_keys do
    :arithmetic
  end

  defp family_for(_op, _term), do: :comparison

  defp preserve_or_wrap_pattern(value) when is_binary(value) do
    if String.contains?(value, ["%", "_"]) do
      value
    else
      "%#{value}%"
    end
  end

  defp preserve_or_wrap_pattern(value) do
    "%#{value}%"
  end
end
```

---

## Projected final state of `lib/ecto_shorts/dynamic_builders/postgres/array_expr.ex`

### Changes

None — file is unchanged.

### Final state

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres.ArrayExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres.ArrayExpr"

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      selected_binding
      |> dispatch_expr(key, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^key)
      )
    end

    defp nil_field_dyn?(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^key))
      )
    end

    defp lower_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp upper_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp lower_not_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp upper_not_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end
  end

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  defp dispatch_expr(binding, key, {:==, nil}) do
    nil_field_dyn?(binding, key)
  end

  defp dispatch_expr(binding, key, {:!=, nil}) do
    field = field_dyn(binding, key)
    Query.dynamic([], not is_nil(^field))
  end

  defp dispatch_expr(binding, key, {:==, values}) when is_list(values) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^field == ^values)
  end

  defp dispatch_expr(binding, key, {:!=, values}) when is_list(values) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^field != ^values)
  end

  defp dispatch_expr(binding, key, {:==, {:lower, value}}) do
    lower_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:==, {:upper, value}}) do
    upper_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:!=, {:lower, value}}) do
    lower_not_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:!=, {:upper, value}}) do
    upper_not_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(_binding, key, {op, {:value, {arith_op, _}}})
       when op in [:==, :!=, :>, :>=, :<, :<=] and arith_op in [:+, :-, :*, :/] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "arithmetic comparison (#{arith_op}) is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(binding, key, {op, {:value, v}}) when op in [:==, :!=, :>, :>=, :<, :<=] do
    dispatch_expr(binding, key, {op, v})
  end

  defp dispatch_expr(binding, key, {:==, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == any(qv))
  end

  defp dispatch_expr(binding, key, {:!=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field != any(qv))
  end

  defp dispatch_expr(binding, key, {:>, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field > any(qv))
  end

  defp dispatch_expr(binding, key, {:>=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field >= any(qv))
  end

  defp dispatch_expr(binding, key, {:<, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field < any(qv))
  end

  defp dispatch_expr(binding, key, {:<=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field <= any(qv))
  end

  defp dispatch_expr(binding, key, {:parent_as, {pb, pf}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:==, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:!=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field != field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:>, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field > field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:>=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field >= field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:<, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field < field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:<=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field <= field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:==, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value in ^field)
  end

  defp dispatch_expr(binding, key, {:!=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value not in ^field)
  end

  defp dispatch_expr(binding, key, {:in, values}) when is_list(values) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? && ?", ^field, ^values))
  end

  defp dispatch_expr(binding, key, {:in, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value in ^field)
  end

  defp dispatch_expr(binding, key, {:count, {:==, 0}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("coalesce(array_length(?, 1), 0)", ^field) == ^0)
  end

  defp dispatch_expr(binding, key, {:count, {:==, value}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("array_length(?, 1)", ^field) == ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:!=, value}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("array_length(?, 1)", ^field) != ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:>, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) > ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:>=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) >= ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:<, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) < ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:<=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) <= ^value)
  end

  defp dispatch_expr(binding, key, {:all, {:==, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? = ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:!=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? != ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:>, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? < ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:>=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <= ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:<, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? > ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:<=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? >= ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:in, values}}) when is_list(values) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?", ^field, ^values))
  end

  defp dispatch_expr(binding, key, {:>, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? < ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:>=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <= ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:<, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? > ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:<=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? >= ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:lower, value}) do
    lower_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:upper, value}) do
    upper_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:like, value}) do
    field = field_dyn(binding, key)
    patterns = wrap_patterns(value)

    Query.dynamic(
      [],
      fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))", ^field, ^patterns)
    )
  end

  defp dispatch_expr(binding, key, {:ilike, value}) do
    field = field_dyn(binding, key)
    patterns = wrap_patterns(value)

    Query.dynamic(
      [],
      fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))", ^field, ^patterns)
    )
  end

  defp dispatch_expr(_binding, key, {op, _}) when op in [:avg, :sum, :max, :min] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "#{op} aggregate is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {:any, _}) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      ":any subquery quantifier is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {wrapper, _}) when wrapper in [:datetime, :date] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "#{wrapper} comparison is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {:parent_as, _}) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      ":parent_as requires a {binding, field} payload, got unexpected form for field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, _key, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr

  defp wrap_patterns(values) when is_list(values) do
    Enum.map(values, &preserve_or_wrap_pattern/1)
  end

  defp wrap_patterns(value) do
    [preserve_or_wrap_pattern(value)]
  end

  defp preserve_or_wrap_pattern(value) when is_binary(value) do
    if String.contains?(value, ["%", "_"]) do
      value
    else
      "%#{value}%"
    end
  end

  defp preserve_or_wrap_pattern(value) do
    "%#{value}%"
  end
end
```

---

## Projected final state of `lib/ecto_shorts/dynamic_builders/postgres/map_expr.ex`

### Changes

None — file is unchanged.

### Final state

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres.MapExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  {target_binding_var, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      selected_binding
      |> dispatch_expr(key, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^key)
      )
    end

    defp nil_field_dyn(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^key))
      )
    end
  end

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  # Nil checks
  defp dispatch_expr(binding, key, {:==, nil}) do
    nil_field_dyn(binding, key)
  end

  defp dispatch_expr(binding, key, {:!=, nil}) do
    f = field_dyn(binding, key)
    Query.dynamic([], not is_nil(^f))
  end

  # Scalar equality/inequality
  defp dispatch_expr(binding, key, {:==, value}) do
    f = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f == ^value)
  end

  defp dispatch_expr(binding, key, {:!=, value}) do
    f = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f != ^value)
  end

  # JSONB containment — @>
  # Tuple form: produced by Normalizer from a single-entry map value.
  # e.g. %{contains: %{key: "value"}} → {:contains, {:key, "value"}}
  defp dispatch_expr(binding, key, {:contains, {k, v}}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^%{k => v}))
  end

  # String form: caller-provided raw JSON string passed through unchanged.
  defp dispatch_expr(binding, key, {:contains, value}) when is_binary(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # List form: for array-typed JSONB values (e.g. JSON arrays).
  defp dispatch_expr(binding, key, {:contains, value}) when is_list(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # JSONB contained-by — <@
  defp dispatch_expr(binding, key, {:contained_by, {k, v}}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^%{k => v}))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_binary(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_list(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  # JSONB key existence — jsonb_exists(field, key)
  # Avoids the ? operator which conflicts with Ecto fragment placeholder syntax.
  defp dispatch_expr(binding, key, {:has_key, value}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists(?, ?)", ^f, ^value))
  end

  # JSONB any-key existence — jsonb_exists_any(field, keys)
  defp dispatch_expr(binding, key, {:has_any_key, values}) when is_list(values) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_any(?, ?)", ^f, ^values))
  end

  # JSONB all-keys existence — jsonb_exists_all(field, keys)
  defp dispatch_expr(binding, key, {:has_all_keys, values}) when is_list(values) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_all(?, ?)", ^f, ^values))
  end

  defp dispatch_expr(_binding, _key, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
```

---

## Projected final state of `lib/ecto_shorts/dynamic_builders/postgres/common_expr.ex`

### Changes

None — file is unchanged.

### Final state

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres.CommonExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  @operators [
    :ids,
    :before,
    :after,
    :until,
    :since,
    :exists,
    :start_date,
    :end_date,
    :since_date,
    :until_date
  ]

  def operators, do: @operators

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(
          unquote(quoted_binding_head) = selected_binding,
          operator,
          negated,
          term,
          _opts
        ) do
      selected_binding
      |> dispatch_expr(operator, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  def dynamic_expr(_selected_binding, _operator, _negated, _term, _opts), do: nil

  defp dispatch_expr(binding, :ids, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn in ^term)
  end

  defp dispatch_expr(binding, :after, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn > ^term)
  end

  defp dispatch_expr(binding, :before, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn < ^term)
  end

  defp dispatch_expr(binding, :since, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, :until, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(binding, operator, term) when operator in [:start_date, :since_date] do
    dyn = field_dyn(binding, :inserted_at)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, operator, term) when operator in [:end_date, :until_date] do
    dyn = field_dyn(binding, :inserted_at)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(_binding, :exists, term) do
    Query.dynamic([], exists(term))
  end

  defp dispatch_expr(_binding, _operator, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
```

