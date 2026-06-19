defmodule EctoShorts.CommonFilters.Schemaless.WindowsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :windows

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "windows shapes (schemaless)" do
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
