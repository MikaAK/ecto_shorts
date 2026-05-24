defmodule EctoShorts.CommonFilters.BooleanCompositionTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe ":or_where with nil dynamic" do
    import ExUnit.CaptureLog

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
end
