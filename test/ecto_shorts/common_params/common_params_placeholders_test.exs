defmodule EctoShorts.CommonParams.PlaceholdersTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonParams.Placeholders

  describe "put_placeholders/3" do
    test "replaces a matching field value with a placeholder tuple" do
      data = %{title: "default", views: 0}
      result = Placeholders.put_placeholders(data, [title: "default"], [])
      assert result.title === {:placeholder, :title}
      assert result.views === 0
    end

    test "leaves the field unchanged when the value does not match the placeholder value" do
      data = %{title: "custom", views: 0}
      result = Placeholders.put_placeholders(data, [title: "default"], [])
      assert result.title === "custom"
    end

    test "leaves the map unchanged when the key is not present" do
      data = %{views: 0}
      result = Placeholders.put_placeholders(data, [title: "default"], [])
      assert result === %{views: 0}
    end

    test "on_placeholder_conflict :nothing leaves the field unchanged (default)" do
      data = %{title: "custom"}

      result =
        Placeholders.put_placeholders(data, [title: "default"], on_placeholder_conflict: :nothing)

      assert result.title === "custom"
    end

    test "on_placeholder_conflict :replace_all replaces the field even when value differs" do
      data = %{title: "custom"}

      result =
        Placeholders.put_placeholders(data, [title: "default"],
          on_placeholder_conflict: :replace_all
        )

      assert result.title === {:placeholder, :title}
    end

    test "on_placeholder_conflict {:replace, keys} replaces only listed keys" do
      data = %{title: "custom", body: "custom body"}

      result =
        Placeholders.put_placeholders(data, [title: "default", body: "default body"],
          on_placeholder_conflict: {:replace, [:title]}
        )

      assert result.title === {:placeholder, :title}
      assert result.body === "custom body"
    end

    test "on_placeholder_conflict {:replace, keys} skips keys not in the list" do
      data = %{title: "custom"}

      result =
        Placeholders.put_placeholders(data, [title: "default"],
          on_placeholder_conflict: {:replace, [:body]}
        )

      assert result.title === "custom"
    end

    test "raises ArgumentError for an unrecognised on_placeholder_conflict value" do
      data = %{title: "custom"}

      assert_raise ArgumentError, fn ->
        Placeholders.put_placeholders(data, [title: "default"], on_placeholder_conflict: :bad)
      end
    end
  end
end
