defmodule EctoShorts.CommonFilters.BooleanCompositionTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe ":or_where with nil dynamic" do
    test "returns query unchanged when or_where term produces no dynamic expression" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{or_where: %{nonexistent_field_xyz_for_nil: 42}},
          []
        )

      assert inspect(actual) == inspect(expected)
    end
  end
end
