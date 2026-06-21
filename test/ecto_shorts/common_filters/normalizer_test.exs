defmodule EctoShorts.CommonFilters.NormalizerTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonFilters.Normalizer

  @post_source EctoShorts.Schema.Post

  describe "normalize/2 — structural keys" do
    test "converts string structural key to atom" do
      result = Normalizer.normalize(%{"where" => %{title: "Hi"}}, nil)
      assert %{where: %{title: "Hi"}} = result
    end

    test "passes through atom structural keys unchanged" do
      result = Normalizer.normalize(%{where: %{title: "Hi"}}, nil)
      assert %{where: %{title: "Hi"}} = result
    end

    test "converts keyword list with string structural key" do
      result = Normalizer.normalize([{"where", %{title: "Hi"}}], nil)
      assert [{:where, %{title: "Hi"}}] = result
    end

    test "passes non-map, non-list through unchanged" do
      assert Normalizer.normalize(:atom, nil) == :atom
      assert Normalizer.normalize(42, nil) == 42
    end
  end

  describe "normalize/2 — :where / predicate container" do
    test "normalizes string field names in :where to atoms via schema reflection" do
      result = Normalizer.normalize(%{"where" => %{"title" => "Hi"}}, @post_source)
      assert %{where: %{title: "Hi"}} = result
    end

    test "leaves unknown string field keys as strings with a warning" do
      import ExUnit.CaptureLog
      log = capture_log(fn ->
        Normalizer.normalize(%{"where" => %{"nonexistent_xyz" => "Hi"}}, @post_source)
      end)
      assert log =~ "Unknown schema identifier"
    end

    test "normalizes nested :field cross-references inside predicate values" do
      result = Normalizer.normalize(
        %{where: %{title: %{field: "body"}}},
        @post_source
      )
      assert %{where: %{title: %{field: :body}}} = result
    end
  end

  describe "normalize/2 — :order_by" do
    test "normalizes string direction key in list form" do
      result = Normalizer.normalize(%{"order_by" => [%{"desc" => "title"}]}, nil)
      assert %{order_by: [{:desc, "title"}]} = result
    end

    test "passes keyword direction entry through unchanged" do
      result = Normalizer.normalize(%{order_by: [desc: :title]}, nil)
      assert %{order_by: [desc: :title]} = result
    end
  end

  describe "normalize/2 — :last" do
    test "normalizes string sort_by / limit keys" do
      result = Normalizer.normalize(%{"last" => %{"sort_by" => "inserted_at", "limit" => 10}}, nil)
      assert %{last: %{sort_by: "inserted_at", limit: 10}} = result
    end
  end

  describe "normalize/2 — :join" do
    test "normalizes JSON-decoded join list with map entry" do
      result = Normalizer.normalize(
        %{"join" => [%{"association" => [source: :comments]}]},
        nil
      )
      assert %{join: [{:association, [source: :comments]}]} = result
    end
  end

  describe "normalize/2 — :with_cte" do
    test "normalizes user-defined CTE name string to atom via String.to_existing_atom" do
      # :my_cte must already be a known atom in the VM (it will be after module load)
      _ = :my_cte
      result = Normalizer.normalize(%{with_cte: %{"my_cte" => %{}}}, nil)
      assert %{with_cte: %{my_cte: %{}}} = result
    end
  end

  describe "normalize_preload/1" do
    test "converts map preload to keyword list" do
      result = Normalizer.normalize_preload(%{comments: nil})
      assert [{:comments, []}] = result
    end

    test "wraps atom in list" do
      result = Normalizer.normalize_preload(:comments)
      assert [:comments] = result
    end

    test "passes keyword list through" do
      result = Normalizer.normalize_preload([comments: nil])
      assert [{:comments, []}] = result
    end
  end
end
