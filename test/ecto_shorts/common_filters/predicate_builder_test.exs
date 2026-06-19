defmodule EctoShorts.CommonFilters.PredicateBuilderTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EctoShorts.CommonFilters.PredicateBuilder
  alias EctoShorts.CommonFilters.Predicate
  alias EctoShorts.Schema.Post

  describe "canonical_op/1" do
    test "passes canonical atoms through" do
      assert PredicateBuilder.canonical_op(:==) == :==
      assert PredicateBuilder.canonical_op(:in) == :in
    end

    test "maps atom nicknames to canonical operators" do
      assert PredicateBuilder.canonical_op(:eq) == :==
      assert PredicateBuilder.canonical_op(:ne) == :!=
      assert PredicateBuilder.canonical_op(:gt) == :>
      assert PredicateBuilder.canonical_op(:gte) == :>=
      assert PredicateBuilder.canonical_op(:lt) == :<
      assert PredicateBuilder.canonical_op(:lte) == :<=
      assert PredicateBuilder.canonical_op(:downcase) == :lower
      assert PredicateBuilder.canonical_op(:upcase) == :upper
    end

    test "maps operator strings (HTTP) through the closed safe list" do
      assert PredicateBuilder.canonical_op("gt") == :>
      assert PredicateBuilder.canonical_op("eq") == :==
      assert PredicateBuilder.canonical_op("overlaps") == :overlaps
      assert PredicateBuilder.canonical_op("ilike") == :ilike
    end

    test "returns :__unknown__ for an unrecognized operator string (never raises/atomizes)" do
      assert PredicateBuilder.canonical_op("definitely_not_an_op") == :__unknown__
    end
  end

  describe "resolve_field/3" do
    test "returns atom field names as-is (trusted)" do
      assert PredicateBuilder.resolve_field(Post, :title, []) == {:ok, :title}
    end

    test "resolves a known string field against the schema" do
      assert PredicateBuilder.resolve_field(Post, "title", []) == {:ok, :title}
    end

    test "warns and skips an unknown string field on a schema-backed source" do
      log =
        capture_log(fn ->
          assert PredicateBuilder.resolve_field(Post, "nope_field", []) == :skip
        end)

      assert log =~ "does not exist on schema"
    end

    test "resolves a string field via :allowed_keys when there is no schema" do
      assert PredicateBuilder.resolve_field({"things", nil}, "name", allowed_keys: ["name"]) == {:ok, :name}
    end

    test "warns and skips a string field not in :allowed_keys" do
      log =
        capture_log(fn ->
          assert PredicateBuilder.resolve_field({"things", nil}, "name", allowed_keys: ["other"]) == :skip
        end)

      assert log =~ "not in the :allowed_keys"
    end

    test "best-effort resolves a string to an existing atom when there is no schema or :allowed_keys" do
      # :title already exists as an atom (the Post schema defines it), so the
      # string resolves without minting anything.
      assert PredicateBuilder.resolve_field({"things", nil}, "title", []) == {:ok, :title}
    end

    test "warns and skips an unknown string field when there is no schema or :allowed_keys" do
      log =
        capture_log(fn ->
          assert PredicateBuilder.resolve_field(
                   {"things", nil},
                   "definitely_not_an_existing_atom_zzz",
                   []
                 ) == :skip
        end)

      assert log =~ "cannot be resolved"
    end
  end

  describe "routing_family/3" do
    test "routes a scalar schema column to :scalar" do
      assert PredicateBuilder.routing_family(Post, :title, []) == :scalar
    end

    test "routes an array schema column to :array" do
      assert PredicateBuilder.routing_family(Post, :tags, []) == :array
    end

    test "uses :field_types over schema reflection" do
      assert PredicateBuilder.routing_family({"t", nil}, :things, field_types: [things: {:array, :string}]) == :array
      assert PredicateBuilder.routing_family({"t", nil}, :doc, field_types: [doc: :map]) == :map
    end

    test "defaults an unknown/typeless column to :scalar" do
      assert PredicateBuilder.routing_family({"t", nil}, :whatever, []) == :scalar
    end
  end

  describe "cast/2" do
    test "passes through when type is nil" do
      assert PredicateBuilder.cast(nil, "anything") == "anything"
    end

    test "casts a scalar to the column type" do
      assert PredicateBuilder.cast(:integer, "5") == 5
    end

    test "casts each element of a list" do
      assert PredicateBuilder.cast(:integer, ["1", "2"]) == [1, 2]
    end

    test "casts list elements using the inner type for an array column" do
      assert PredicateBuilder.cast({:array, :integer}, ["1", "2"]) == [1, 2]
    end
  end

  describe "build/4 — comparison family (returns a list of terms)" do
    test "bare scalar becomes equality, cast to the column type" do
      assert PredicateBuilder.build(Post, :views, "5", []) ==
               {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:==, 5}}]}
    end

    test "operator nickname canonicalizes and casts" do
      assert PredicateBuilder.build(Post, :views, %{gt: "10"}, []) ==
               {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:>, 10}}]}
    end

    test "a multi-operator value map yields one term per operator (reduce; AND)" do
      assert {:ok, terms} = PredicateBuilder.build(Post, :views, %{gt: "10", lte: "100"}, [])
      assert Enum.map(terms, & &1.expr) |> Enum.sort() == Enum.sort([{:>, 10}, {:<=, 100}])
      assert Enum.all?(terms, &(&1.field == :views and &1.negated == false))
    end

    test "nil becomes a nil-check (no cast)" do
      assert PredicateBuilder.build(Post, :published_at, %{eq: nil}, []) ==
               {:ok, [%Predicate{field: :published_at, routing: :scalar, negated: false, expr: {:==, nil}}]}
    end

    test "bare list is sugar for eq (routing decides membership vs equality)" do
      assert PredicateBuilder.build(Post, :views, ["1", "2"], []) ==
               {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:==, [1, 2]}}]}
    end

    test "explicit in/nin keep their operator" do
      assert {:ok, [%Predicate{expr: {:in, [1, 2]}}]} = PredicateBuilder.build(Post, :views, %{in: ["1", "2"]}, [])
      assert {:ok, [%Predicate{expr: {:nin, [1, 2]}}]} = PredicateBuilder.build(Post, :views, %{nin: ["1", "2"]}, [])
    end

    test "like auto-wraps a plain pattern but keeps an explicit one" do
      assert {:ok, [%Predicate{expr: {:like, "%al%"}}]} = PredicateBuilder.build(Post, :title, %{like: "al"}, [])
      assert {:ok, [%Predicate{expr: {:like, "al%"}}]} = PredicateBuilder.build(Post, :title, %{like: "al%"}, [])
    end

    test "text transform wraps the value side" do
      assert {:ok, [%Predicate{expr: {:==, {:lower, "AL"}}}]} =
               PredicateBuilder.build(Post, :title, %{eq: %{downcase: "AL"}}, [])
    end

    test "aggregate nests a comparison" do
      assert {:ok, [%Predicate{expr: {:avg, {:>, 10}}}]} =
               PredicateBuilder.build(Post, :views, %{avg: %{gt: "10"}}, [])
    end

    test "not is lifted into the negated slot (nested toggles)" do
      assert {:ok, [%Predicate{negated: true, expr: {:==, 5}}]} =
               PredicateBuilder.build(Post, :views, %{not: %{eq: "5"}}, [])

      assert {:ok, [%Predicate{negated: false, expr: {:==, 5}}]} =
               PredicateBuilder.build(Post, :views, %{not: %{not: %{eq: "5"}}}, [])
    end

    test "array column: bare list is eq (routing :array → exact equality downstream)" do
      assert {:ok, [%Predicate{routing: :array, expr: {:==, ["a", "b"]}}]} =
               PredicateBuilder.build(Post, :tags, ["a", "b"], [])
    end

    test "overlaps produces an array-overlap term and forces :array routing" do
      assert {:ok, [%Predicate{routing: :array, expr: {:overlaps, ["a", "b"]}}]} =
               PredicateBuilder.build({"posts", nil}, :tags, %{overlaps: ["a", "b"]}, [])
    end

    test "date-math: bare ago map tidies to a :datetime interval keyword" do
      assert {:ok, [%Predicate{expr: {:>, {:datetime, {:ago, [count: 1, interval: "day"]}}}}]} =
               PredicateBuilder.build(Post, :inserted_at, %{gt: %{ago: %{count: 1, unit: "day"}}}, [])
    end

    test "date-math: date wrapper with shift tidies to a :date interval keyword" do
      assert {:ok, [%Predicate{expr: {:>=, {:date, {:shift, [count: 7, interval: "day"]}}}}]} =
               PredicateBuilder.build(
                 Post,
                 :inserted_at,
                 %{gte: %{date: %{shift: %{count: 7, unit: "day"}}}},
                 []
               )
    end

    test "field operand on the current binding" do
      assert {:ok, [%Predicate{expr: {:>, {:field, :id}}}]} =
               PredicateBuilder.build(Post, :views, %{gt: %{field: :id}}, [])
    end

    test "field operand with a sibling binding records {binding, field}" do
      assert {:ok, [%Predicate{expr: {:>, {:field, {:author, :age}}}}]} =
               PredicateBuilder.build(Post, :views, %{gt: %{field: :age, as: :author}}, [])
    end

    test "value operand is always a single literal (cast), never membership" do
      assert {:ok, [%Predicate{expr: {:==, {:value, [1, 2]}}}]} =
               PredicateBuilder.build(Post, :views, %{eq: %{value: ["1", "2"]}}, [])
    end

    test "binary arithmetic operand (field SYM value) tidies to a value-wrapped term" do
      assert {:ok, [%Predicate{expr: {:>, {:value, {:+, {{:field, :id}, {:value, 5}}}}}}]} =
               PredicateBuilder.build(Post, :views, %{gt: %{add: [%{field: :id}, %{value: "5"}]}}, [])
    end

    test "arithmetic with three operands raises (binary only)" do
      assert_raise EctoShorts.FilterError, fn ->
        PredicateBuilder.build(
          Post,
          :views,
          %{gt: %{add: [%{field: :a}, %{field: :b}, %{value: 1}]}},
          []
        )
      end
    end

    test "an unknown operator entry is dropped (warn); other entries survive" do
      log =
        capture_log(fn ->
          assert {:ok, [%Predicate{expr: {:>, 1}}]} =
                   PredicateBuilder.build(Post, :views, %{"bogus" => 1, gt: 1}, [])
        end)

      assert log =~ "operator"
    end

    test "unknown field skips entirely (before building any term)" do
      capture_log(fn -> assert PredicateBuilder.build(Post, "nope_field", 1, []) == :skip end)
    end
  end
end
