defmodule EctoShorts.CommonFilters.OrderModifierTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "order modifier shapes" do
    # A bare atom for `prepend_order_by` defaults to `desc:` order, unlike `order_by:`
    # where a bare atom defaults to `asc:`.
    test "matches Ecto.Query for a root prepend_order_by atom" do
      expected = prepend_order_by(Post, [], desc: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root prepend_order_by ordered keyword list" do
      expected =
        prepend_order_by(
          Post,
          [],
          asc: :published_at,
          desc: :title
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [asc: :published_at, desc: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding prepend_order_by atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = prepend_order_by(source, [author: a], desc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                prepend_order_by: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding prepend_order_by ordered keyword list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      expected = prepend_order_by(source, [author: a], asc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                prepend_order_by: [asc: :first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding prepend_order_by atom" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = prepend_order_by(source, [_, a], desc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                prepend_order_by: :first_name
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding prepend_order_by ordered keyword list" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = prepend_order_by(source, [_, a], asc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                prepend_order_by: [asc: :first_name]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for reverse_order on an existing ordered query" do
      source = from(p in Post, order_by: [asc: p.title])
      expected = reverse_order(source)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{reverse_order: true},
          []
        )

      assert_query(expected, actual)
    end

    # `reverse_order:` is applied after all other params in the same call, including
    # `order_by:` values that appear in the same params map.
    test "matches Ecto.Query for reverse_order after local order_by params" do
      expected =
        Post
        |> order_by([], asc: :title)
        |> reverse_order()

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: :title, reverse_order: true},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "order_by list shapes" do
    test "orders by a list of direction-field tuples" do
      expected = from(p in Post, order_by: [asc: p.title, desc: p.views])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: :title, desc: :views]},
          []
        )

      assert_query(expected, actual)
    end

    test "orders by a list of bare atoms defaulting to asc" do
      expected = from(p in Post, order_by: [asc: p.title, asc: p.views])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [:title, :views]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "prepend_order_by list shapes" do
    test "prepend_order_by with a list of direction-field tuples" do
      expected = prepend_order_by(Post, [], asc: :title, desc: :views)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [asc: :title, desc: :views]},
          []
        )

      assert_query(expected, actual)
    end

    test "prepend_order_by with a list of bare atoms defaulting to desc" do
      expected = prepend_order_by(Post, [], desc: :title, desc: :views)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [:title, :views]},
          []
        )

      assert_query(expected, actual)
    end

    test "prepend_order_by with named binding and a list of direction-field tuples" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name

      expected =
        prepend_order_by(source, [author: a],
          asc: field(a, ^field_name),
          desc: field(a, ^field_name)
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{prepend_order_by: [asc: :first_name, desc: :first_name]}}},
          []
        )

      assert_query(expected, actual)
    end

    test "prepend_order_by with positional binding and a list of direction-field tuples" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      expected = prepend_order_by(source, [_, a], asc: field(a, ^field_name))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{prepend_order_by: [asc: :first_name]}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "order_by DynamicExpr and fallthrough paths" do
    test "order_by passes a DynamicExpr entry through unchanged in a list" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [dyn]},
          []
        )

      refute is_nil(actual)
    end

    test "order_by passes a non-atom non-dynamic list entry through as-is (other branch)" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: dyn]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "order_by with a non-binding selector uses the fallthrough build_order_by" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: :title, desc: :views]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "prepend_order_by passes a DynamicExpr entry through unchanged in a list" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [dyn]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "prepend_order_by passes a non-atom non-dynamic list entry through as-is (other branch)" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [asc: dyn]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "prepend_order_by with a raw keyword list uses fallthrough path" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: [asc: :title]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "order_by edge cases" do
    test "accepts a map input for order_by" do
      # Map.to_list(%{asc: :title}) = [{:asc, :title}] — valid direction-field tuple
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: %{asc: :title}},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "skips invalid schema field in order_by list and returns query unchanged" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{order_by: [{:asc, :nonexistent_field}]},
              []
            )

          assert inspect(actual) == inspect(expected)
        end)

      assert log =~ "nonexistent_field"
    end
  end

  describe "prepend_order_by edge cases" do
    test "accepts a map input for prepend_order_by" do
      # Map input: Map.to_list(%{asc: :title}) = [{:asc, :title}] — valid direction-field tuple
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{prepend_order_by: %{asc: :title}},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "skips invalid schema field in ordered-tuple entry and returns query unchanged" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{prepend_order_by: [{:asc, :nonexistent_field}]},
              []
            )

          assert inspect(actual) == inspect(expected)
        end)

      assert log =~ "nonexistent_field"
    end

    test "skips invalid schema field in plain-atom entry and returns query unchanged" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{prepend_order_by: [:nonexistent_field]},
              []
            )

          assert inspect(actual) == inspect(expected)
        end)

      assert log =~ "nonexistent_field"
    end
  end

  describe "reverse_order nil" do
    test "reverses the query order when reverse_order is nil" do
      source = from(p in Post, order_by: [asc: p.title])
      expected = reverse_order(source)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{reverse_order: nil},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "reverse_order warning" do
    test "logs a warning and returns the query unchanged when reverse_order is not true" do
      expected = from(p in Post, order_by: [asc: p.title])

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              expected,
              %{reverse_order: false},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :reverse_order value to be true"
    end
  end
end
