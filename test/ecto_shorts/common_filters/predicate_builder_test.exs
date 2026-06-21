defmodule EctoShorts.CommonFilters.PredicateBuilderTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag feature: :predicate_builder
  import Ecto.Query
  import ExUnit.CaptureLog

  alias EctoShorts.CommonFilters.PredicateBuilder
  alias EctoShorts.CommonFilters.Predicate
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.User
  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.EnumParent
  alias EctoShorts.Schema.EnumSchema


  describe "canonical_op/1" do
    test "passes canonical atoms through" do
      assert :== = PredicateBuilder.canonical_op(:==)
      assert :in = PredicateBuilder.canonical_op(:in)
    end

    test "maps atom nicknames to canonical operators" do
      assert :== = PredicateBuilder.canonical_op(:eq)
      assert :!= = PredicateBuilder.canonical_op(:ne)
      assert :> = PredicateBuilder.canonical_op(:gt)
      assert :>= = PredicateBuilder.canonical_op(:gte)
      assert :< = PredicateBuilder.canonical_op(:lt)
      assert :<= = PredicateBuilder.canonical_op(:lte)
      assert :lower = PredicateBuilder.canonical_op(:downcase)
      assert :upper = PredicateBuilder.canonical_op(:upcase)
    end

    test "maps operator strings (HTTP) through the closed safe list" do
      assert :> = PredicateBuilder.canonical_op("gt")
      assert :== = PredicateBuilder.canonical_op("eq")
      assert :overlaps = PredicateBuilder.canonical_op("overlaps")
      assert :ilike = PredicateBuilder.canonical_op("ilike")
    end

    test "returns :__unknown__ for an unrecognized operator string (never raises/atomizes)" do
      assert :__unknown__ = PredicateBuilder.canonical_op("definitely_not_an_op")
    end
  end

  describe "resolve_field/3" do
    test "returns atom field names as-is (trusted)" do
      assert {:ok, :title} = PredicateBuilder.resolve_field(Post, :title, [])
    end

    test "resolves a known string field against the schema" do
      assert {:ok, :title} = PredicateBuilder.resolve_field(Post, "title", [])
    end

    test "warns and skips an unknown string field on a schema-backed source" do
      log =
        capture_log(fn ->
          assert match?({:error, _}, PredicateBuilder.resolve_field(Post, "nope_field", []))
        end)

      assert log =~ "does not exist on schema"
    end

    test "resolves a string field via :allowed_keys when there is no schema" do
      assert {:ok, :name} = PredicateBuilder.resolve_field({"things", nil}, "name", allowed_keys: ["name"])
    end

    test "warns and skips a string field not in :allowed_keys" do
      log =
        capture_log(fn ->
          assert match?({:error, _}, PredicateBuilder.resolve_field({"things", nil}, "name", allowed_keys: ["other"]))
        end)

      assert log =~ "not in the :allowed_keys"
    end

    test "best-effort resolves a string to an existing atom when there is no schema or :allowed_keys" do
      # :title already exists as an atom (the Post schema defines it), so the
      # string resolves without minting anything.
      assert {:ok, :title} = PredicateBuilder.resolve_field({"things", nil}, "title", [])
    end

    test "warns and skips an unknown string field when there is no schema or :allowed_keys" do
      log =
        capture_log(fn ->
          assert match?({:error, _}, PredicateBuilder.resolve_field(
                   {"things", nil},
                   "definitely_not_an_existing_atom_zzz",
                   []
                 ))
        end)

      assert log =~ "cannot be resolved"
    end
  end

  describe "routing_family/3" do
    test "routes a scalar schema column to :scalar" do
      assert :scalar = PredicateBuilder.routing_family(Post, :title, [])
    end

    test "routes an array schema column to :array" do
      assert :array = PredicateBuilder.routing_family(Post, :tags, [])
    end

    test "uses :field_types over schema reflection" do
      assert :array = PredicateBuilder.routing_family({"t", nil}, :things, field_types: [things: {:array, :string}])
      assert :map = PredicateBuilder.routing_family({"t", nil}, :doc, field_types: [doc: :map])
    end

    test "defaults an unknown/typeless column to :scalar" do
      assert :scalar = PredicateBuilder.routing_family({"t", nil}, :whatever, [])
    end
  end

  describe "cast/2" do
    test "passes through when type is nil" do
      assert "anything" = PredicateBuilder.cast(nil, "anything")
    end

    test "casts a scalar to the column type" do
      assert 5 = PredicateBuilder.cast(:integer, "5")
    end

    test "casts each element of a list" do
      assert [1, 2] = PredicateBuilder.cast(:integer, ["1", "2"])
    end

    test "casts list elements using the inner type for an array column" do
      assert [1, 2] = PredicateBuilder.cast({:array, :integer}, ["1", "2"])
    end
  end

  describe "build/4 — comparison family (returns a list of terms)" do
    test "bare scalar becomes equality, cast to the column type" do
      assert {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:==, 5}}]} =
               PredicateBuilder.build(Post, :views, "5", [])
    end

    test "operator nickname canonicalizes and casts" do
      assert {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:>, 10}}]} =
               PredicateBuilder.build(Post, :views, %{gt: "10"}, [])
    end

    test "a multi-operator value map yields one term per operator (reduce; AND)" do
      assert {:ok, terms} = PredicateBuilder.build(Post, :views, %{gt: "10", lte: "100"}, [])
      assert (terms |> Enum.map(& &1.expr) |> Enum.sort()) === Enum.sort([{:>, 10}, {:<=, 100}])
      assert Enum.all?(terms, &(&1.field === :views and &1.negated === false))
    end

    test "nil becomes a nil-check (no cast)" do
      assert {:ok, [%Predicate{field: :published_at, routing: :scalar, negated: false, expr: {:==, nil}}]} =
               PredicateBuilder.build(Post, :published_at, %{eq: nil}, [])
    end

    test "bare list is sugar for eq (routing decides membership vs equality)" do
      assert {:ok, [%Predicate{field: :views, routing: :scalar, negated: false, expr: {:==, [1, 2]}}]} =
               PredicateBuilder.build(Post, :views, ["1", "2"], [])
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
      capture_log(fn -> assert match?({:error, _}, PredicateBuilder.build(Post, "nope_field", 1, [])) end)
    end
  end

  # ---- merged from boolean_composition ----
  describe ":or_where with nil dynamic" do
  @describetag feature: :boolean_composition

    test "returns query unchanged when or_where term produces no dynamic expression" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{or_where: %{nonexistent_field_xyz_for_nil: 42}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field"
      assert log =~ "does not exist on schema"
    end
  end

  # ---- merged from typed_value_casting ----
  describe "typed predicate casting" do
  @describetag feature: :typed_value_casting
    test "casts a string integer on a root schema field" do
      expected = from(p in Post, where: p.id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{id: "1"},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer for a named binding field" do
      source =
        from(p in Post,
          join: u in assoc(p, :author),
          as: :author
        )

      expected = where(source, [author: u], u.age == ^42)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{age: "42"}}},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer for a positional binding field" do
      source =
        from(p in Post,
          join: u in assoc(p, :author)
        )

      expected = where(source, [_, u], u.age == ^42)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{age: "42"}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "typed casting with comparison operators" do
  @describetag feature: :typed_value_casting
    test "casts a string integer with the > operator" do
      expected = from(p in Post, where: p.views > ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{>: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the >= operator" do
      expected = from(p in Post, where: p.views >= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{>=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the < operator" do
      expected = from(p in Post, where: p.views < ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{<: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the <= operator" do
      expected = from(p in Post, where: p.views <= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{<=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the gt alias" do
      expected = from(p in Post, where: p.views > ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{gt: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the gte alias" do
      expected = from(p in Post, where: p.views >= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{gte: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the lt alias" do
      expected = from(p in Post, where: p.views < ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{lt: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the lte alias" do
      expected = from(p in Post, where: p.views <= ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{lte: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the != operator" do
      expected = from(p in Post, where: p.views != ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the ne alias" do
      expected = from(p in Post, where: p.views != ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{ne: "10"}}, [])

      assert_query(expected, actual)
    end

    test "casts a string integer with the eq alias" do
      expected = from(p in Post, where: p.views == ^10)

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{eq: "10"}}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting for list membership" do
  @describetag feature: :typed_value_casting
    test "casts a list of string integers for == operator" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{==: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a list of string integers for != operator" do
      expected = from(p in Post, where: p.views not in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{!=: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a list of string integers for in operator" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{in: ["10", "20"]}}, [])

      assert_query(expected, actual)
    end

    test "casts a bare list of string integers as membership" do
      expected = from(p in Post, where: p.views in ^[10, 20])

      actual = CommonFilters.convert_params_to_filter(Post, %{views: ["10", "20"]}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting for array fields" do
  @describetag feature: :typed_value_casting
    test "casts string elements in a list for array field equality" do
      expected = from(p in Post, where: p.tags == ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(Post, %{tags: %{==: ["elixir", "ecto"]}}, [])

      assert_query(expected, actual)
    end

    test "casts string elements in a list for array field inequality" do
      expected = from(p in Post, where: p.tags != ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(Post, %{tags: %{!=: ["elixir", "ecto"]}}, [])

      assert_query(expected, actual)
    end

    test "casts string elements for array field in operator" do
      expected = from(p in Post, where: p.tags == ^["elixir"])

      actual = CommonFilters.convert_params_to_filter(Post, %{tags: ["elixir"]}, [])

      assert_query(expected, actual)
    end
  end

  describe "typed casting with value wrapper" do
  @describetag feature: :typed_value_casting
    test "casts a string integer inside a {:value, value} wrapper" do
      expected = from(p in Post, where: p.views > ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: {:value, "10"}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "typed casting for boolean fields" do
  @describetag feature: :typed_value_casting
    test "casts a string boolean for equality" do
      expected = from(p in Post, where: p.published == ^true)

      actual = CommonFilters.convert_params_to_filter(Post, %{published: "true"}, [])

      assert_query(expected, actual)
    end
  end

  # ---- merged from enum_casting ----
  describe "Ecto.Enum casting" do
  @describetag feature: :enum_casting
    test "casts a bare Ecto.Enum atom to its integer mapping" do
      expected = from(e in EnumSchema, where: e.status == ^1)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: :published}, [])

      assert_sql(expected, actual)
    end

    test "casts an operator-wrapped Ecto.Enum atom" do
      expected = from(e in EnumSchema, where: e.status != ^2)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: %{!=: :archived}}, [])

      assert_sql(expected, actual)
    end

    test "casts a list of Ecto.Enum atoms for membership" do
      expected = from(e in EnumSchema, where: e.status in ^[1, 2])

      actual =
        CommonFilters.convert_params_to_filter(EnumSchema, %{status: [:published, :archived]}, [])

      assert_sql(expected, actual)
    end

    test "passes through non-enum values unchanged" do
      expected = from(e in EnumSchema, where: e.views == ^42)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{views: 42}, [])

      assert_sql(expected, actual)
    end

    test "passes through nil without casting" do
      expected = from(e in EnumSchema, where: is_nil(e.status))
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: nil}, [])

      assert_sql(expected, actual)
    end
  end

  describe "Ecto.Enum casting through associations" do
  @describetag feature: :enum_casting
    test "casts Ecto.Enum atom in nested association filter" do
      expected =
        from(p in EnumParent,
          join: e in assoc(p, :enum_schema),
          as: :enum_schema,
          where: e.status == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          EnumParent,
          %{enum_schema: %{status: :published}},
          []
        )

      assert_sql(expected, actual)
    end
  end

  # ---- merged from field_types_opt ----
  describe "field_types: opt for array fields" do
  @describetag feature: :field_types_opt
    # Without field_types, a schemaless query treats all fields as scalars.
    # A list value produces membership (field IN ^list), not array overlap.
    test "without field_types, schemaless list value uses scalar membership semantics" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: ["elixir", "ecto"]},
          []
        )

      assert_query(expected, actual)
    end

    test "with field_types array, list value uses array membership semantics" do
      expected = from(p in "posts", where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: "elixir"},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "with field_types array, explicit in: list uses array overlap semantics" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["elixir", "ecto"]))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{in: ["elixir", "ecto"]}},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "field_types also works with schema-backed sources (overrides reflection)" do
      expected = from(p in Post, where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{tags: "elixir"},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end
  end

  describe "field_types: opt for map fields" do
  @describetag feature: :field_types_opt
    test "with field_types :map, uses JSONB containment semantics" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "with field_types {:map, :string}, uses JSONB containment semantics" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: {:map, :string}]
        )

      assert_query(expected, actual)
    end

    test "with field_types :map, has_key uses jsonb_exists" do
      expected =
        from(p in "data_stores",
          where: fragment("jsonb_exists(?, ?)", p.data, ^"role")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{has_key: "role"}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from invalid_schema_field ----
  describe "invalid schema field guards" do
  @describetag feature: :invalid_schema_field
    test "keeps the query unchanged when where targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{does_not_exist: 1}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when having targets an invalid field" do
      expected = from(p in Post, group_by: p.id)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{group_by: :id, having: %{does_not_exist: %{avg: %{>: 1}}}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when join on only contains invalid fields" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{join: [schema: [source: User, as: :user, on: %{does_not_exist: 1}]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when order_by targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{order_by: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when group_by targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{group_by: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when distinct targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{distinct: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end
  end

  describe "association given a scalar (D-RAISE)" do
  @describetag feature: :invalid_schema_field
    test "an association filter given a non-map/keyword value raises" do
      assert_raise EctoShorts.FilterError, ~r/association/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{comments: "x"}, [])
      end
    end
  end

  # ---- merged from boolean_composition (schemaless) ----
  describe "boolean composition (schemaless)" do
    @describetag feature: :boolean_composition
    @describetag schema_mode: :schemaless
    test ":and with a single field produces a where clause" do
      expected = from(p in "posts", where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{and: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":or with a single field produces an or_where clause" do
      expected = from(p in "posts", or_where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{or: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":or with a list of param maps reduces as or_where for each entry" do
      expected =
        from(p in "posts",
          or_where: p.views == ^15,
          or_where: p.views == ^20
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{or: [%{views: 15}, %{views: 20}]},
          []
        )

      assert_query(expected, actual)
    end

    test "keyword list where: entries AND together" do
      expected = from(p in "posts", where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [where: %{published: true}, where: %{views: 5}],
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- :all / :any boolean grouper aliases (schemaless) ----
  describe ":all / :any boolean grouper aliases (schemaless)" do
    @describetag feature: :boolean_composition
    @describetag schema_mode: :schemaless

    test ":all with a single field produces the same where clause as :and" do
      expected = from(p in "posts", where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{all: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":all with multiple fields ANDs the conditions together" do
      expected = from(p in "posts", where: p.published == ^true, where: p.views == ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{all: %{published: true, views: 5}},
          []
        )

      assert_query(expected, actual)
    end

    test ":any with a single field produces the same or_where clause as :or" do
      expected = from(p in "posts", or_where: p.views == ^15)
      actual = CommonFilters.convert_params_to_filter("posts", %{any: %{views: 15}}, [])

      assert_query(expected, actual)
    end

    test ":any with a list of param maps reduces as or_where for each entry" do
      expected =
        from(p in "posts",
          or_where: p.views == ^15,
          or_where: p.views == ^20
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{any: [%{views: 15}, %{views: 20}]},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from field_types_opt (schemaless) ----
  describe "field_types: opt (schemaless)" do
    @describetag feature: :field_types_opt
    @describetag schema_mode: :schemaless
    test "with field_types :map, has_key uses jsonb_exists" do
      expected =
        from(p in "data_stores",
          where: fragment("jsonb_exists(?, ?)", p.data, ^"role")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{has_key: "role"}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "with field_types :map, containment uses @>" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "without field_types, fields use scalar semantics regardless of name" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: ["elixir", "ecto"]},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from invalid_schema_field (schemaless) ----
  describe "invalid schema fields on schemaless sources" do
    @describetag feature: :invalid_schema_field
    @describetag schema_mode: :schemaless
    test "keeps arbitrary fields in where filters" do
      expected = from(p in "posts", where: p.does_not_exist == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{does_not_exist: 1},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps arbitrary fields in select filters" do
      expected = from(p in "posts", select: p.does_not_exist)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: :does_not_exist},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps arbitrary fields in order_by filters" do
      expected = from(p in "posts", order_by: [asc: p.does_not_exist])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :does_not_exist},
          []
        )

      assert_query(expected, actual)
    end
  end
end
