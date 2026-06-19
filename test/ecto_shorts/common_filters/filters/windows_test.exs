defmodule EctoShorts.CommonFilters.WindowsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :windows

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog


  describe "windows shapes" do
    test "matches Ecto.Query for a root windows partition_by atom" do
      field_name = :author_id

      expected =
        windows(Post, [p], post_window: [partition_by: [field(p, ^field_name)], order_by: []])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{windows: [post_window: [partition_by: :author_id]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root windows partition_by list and order_by keyword list" do
      partition_field = :author_id
      order_field = :inserted_at

      expected =
        windows(Post, [p],
          post_window: [
            partition_by: [field(p, ^partition_field), field(p, ^:title)],
            order_by: [desc: field(p, ^order_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            windows: [
              post_window: [partition_by: [:author_id, :title], order_by: [desc: :inserted_at]]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root windows frame dynamic expression" do
      frame_expr = dynamic([], fragment("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"))

      expected =
        windows(Post, [p], post_window: [partition_by: [], order_by: [], frame: ^frame_expr])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{windows: [post_window: [frame: frame_expr]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for windows nested under a named binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name

      expected =
        windows(source, [author: a],
          author_window: [
            partition_by: [field(a, ^field_name)],
            order_by: [desc: field(a, ^field_name)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                windows: [
                  author_window: [partition_by: :first_name, order_by: [desc: :first_name]]
                ]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for windows nested under a positional binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name

      expected =
        windows(source, [p, a],
          author_window: [
            partition_by: [field(a, ^field_name)],
            order_by: [desc: field(a, ^field_name)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                windows: [
                  author_window: [partition_by: :first_name, order_by: [desc: :first_name]]
                ]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for multiple windows in one payload" do
      author_field = :author_id
      inserted_at_field = :inserted_at

      expected =
        Post
        |> windows([p],
          post_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          recent_window: [partition_by: [], order_by: [desc: field(p, ^inserted_at_field)]]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [
            windows: [
              post_window: [partition_by: :author_id],
              recent_window: [order_by: [desc: :inserted_at]]
            ]
          ],
          []
        )

      assert_query(expected, actual)
    end

    # `window: :name` copies partition and order from the referenced window at
    # filter-build time. Local keys in the child window override inherited values.
    # Chaining is supported: a child can reference a window that itself references
    # another.
    test "matches Ecto.Query for a root window reference by name only" do
      author_field = :author_id

      expected =
        Post
        |> windows([p],
          base_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          child_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            windows: [
              base_window: [partition_by: :author_id],
              child_window: [window: :base_window]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root window reference with local overrides" do
      author_field = :author_id
      inserted_at_field = :inserted_at

      expected =
        Post
        |> windows([p],
          base_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          child_window: [
            partition_by: [field(p, ^author_field)],
            order_by: [desc: field(p, ^inserted_at_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            windows: [
              base_window: [partition_by: :author_id],
              child_window: [window: :base_window, order_by: [desc: :inserted_at]]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for chained root window references" do
      author_field = :author_id
      inserted_at_field = :inserted_at
      id_field = :id

      expected =
        Post
        |> windows([p],
          c_window: [
            partition_by: [field(p, ^author_field)],
            order_by: [asc: field(p, ^id_field)]
          ]
        )
        |> windows([p],
          b_window: [
            partition_by: [field(p, ^author_field)],
            order_by: [desc: field(p, ^inserted_at_field)]
          ]
        )
        |> windows([p],
          a_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            windows: [
              c_window: [window: :b_window, order_by: [asc: :id]],
              b_window: [window: :a_window, order_by: [desc: :inserted_at]],
              a_window: [partition_by: :author_id]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for window references nested under a named binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      field_name = :first_name
      order_field = :inserted_at

      expected =
        source
        |> windows([author: a],
          base_window: [partition_by: [field(a, ^field_name)], order_by: []]
        )
        |> windows([author: a],
          child_window: [
            partition_by: [field(a, ^field_name)],
            order_by: [desc: field(a, ^order_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                windows: [
                  base_window: [partition_by: :first_name],
                  child_window: [window: :base_window, order_by: [desc: :inserted_at]]
                ]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for window references nested under a positional binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      field_name = :first_name
      order_field = :inserted_at

      expected =
        source
        |> windows([p, a],
          base_window: [partition_by: [field(a, ^field_name)], order_by: []]
        )
        |> windows([p, a],
          child_window: [
            partition_by: [field(a, ^field_name)],
            order_by: [desc: field(a, ^order_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                windows: [
                  base_window: [partition_by: :first_name],
                  child_window: [window: :base_window, order_by: [desc: :inserted_at]]
                ]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # Window reference cycles are detected at filter-build time. A cycle produces a
    # log warning and leaves the query unchanged.
    test "keeps the query unchanged when a window reference cycle exists" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                windows: [
                  a_window: [window: :b_window],
                  b_window: [window: :a_window]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Detected cyclic :windows reference involving :a_window"
    end

    test "keeps the query unchanged when a window references itself" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{windows: [self_window: [window: :self_window]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Detected cyclic :windows reference involving :self_window"
    end

    # `:frame` requires an `Ecto.Query.DynamicExpr`. Raw strings are not accepted.
    test "keeps the query unchanged when frame is not a dynamic expression" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{
                windows: [
                  post_window: [frame: "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"]
                ]
              },
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :frame for :post_window to be an Ecto dynamic expression"
    end
  end

  describe "windows order_by extended paths" do
    test "matches Ecto.Query for windows with order_by as a keyword list" do
      order_field = :inserted_at

      expected =
        windows(Post, [p],
          post_window: [
            partition_by: [],
            order_by: [{:desc, field(p, ^order_field)}]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{windows: [post_window: [order_by: [desc: :inserted_at]]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for windows with partition_by as nil (empty list result)" do
      order_field = :inserted_at

      expected =
        windows(Post, [p],
          post_window: [
            partition_by: [],
            order_by: [{:desc, field(p, ^order_field)}]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{windows: [post_window: [order_by: [desc: :inserted_at], partition_by: nil]]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "windows edge cases" do
    test "accepts a map input for windows" do
      source = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{windows: %{w: [partition_by: :author_id]}},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "logs warning and returns query unchanged for non-map, non-keyword windows value" do
      import ExUnit.CaptureLog
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{windows: :invalid},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :windows params to be a map or keyword list"
    end

    test "accepts a plain atom in order_by within a window definition" do
      source = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{windows: [w: [order_by: :author_id]]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  # ---- merged from windows (schemaless) ----
  describe "windows shapes (schemaless)" do
    @describetag feature: :windows
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root windows partition_by atom" do
      field_name = :author_id

      expected =
        windows("posts", [p], post_window: [partition_by: [field(p, ^field_name)], order_by: []])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{windows: [post_window: [partition_by: :author_id]]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
