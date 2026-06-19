defmodule EctoShorts.CommonParams.TimestampsTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonParams.Timestamps
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.TimestampFree

  @dt ~U[2026-01-01 00:00:00Z]

  describe "put_timestamps/4 inserted_at gating" do
    test "schema lacking :inserted_at omits it by default" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, [])

      refute Map.has_key?(result, :inserted_at)
    end

    test "schema defining :inserted_at gets it (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, Post, [])

      assert Map.has_key?(result, :inserted_at)
    end

    test "schemaless source gets :inserted_at (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, nil, [])

      assert Map.has_key?(result, :inserted_at)
    end

    test "explicit :inserted_at value forces the key onto a schema lacking it" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, inserted_at: @dt)

      assert Map.has_key?(result, :inserted_at)
    end

    test "explicit :inserted_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, inserted_at_source: :created_on)

      assert Map.has_key?(result, :created_on)
    end
  end
end
