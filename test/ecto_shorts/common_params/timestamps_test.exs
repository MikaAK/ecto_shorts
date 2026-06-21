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

  describe "put_timestamps/4 updated_at gating" do
    test "schema lacking :updated_at omits it by default" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, [])

      refute Map.has_key?(result, :updated_at)
    end

    test "schema defining :updated_at gets it (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, Post, [])

      assert Map.has_key?(result, :updated_at)
    end

    test "schemaless source gets :updated_at (regression)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, nil, [])

      assert Map.has_key?(result, :updated_at)
    end

    test "explicit :updated_at value forces the key onto a schema lacking it" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, updated_at: @dt)

      assert @dt = result[:updated_at]
    end

    test "explicit :updated_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, updated_at_source: :changed_on)

      assert Map.has_key?(result, :changed_on)
    end
  end

  describe "put_set_updated_at/4 gating" do
    test "schema lacking :updated_at leaves :set untouched by default" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, [])

      refute Keyword.has_key?(result[:set], :updated_at)
    end

    test "schema defining :updated_at adds it to :set (regression)" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, Post, [])

      assert Keyword.has_key?(result[:set], :updated_at)
    end

    test "schemaless source adds :updated_at to :set (regression)" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, nil, [])

      assert Keyword.has_key?(result[:set], :updated_at)
    end

    test "explicit :updated_at value forces it onto a schema lacking the field" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, updated_at: @dt)

      assert @dt = result[:set][:updated_at]
    end

    test "explicit :updated_at_source forces the custom key onto a schema lacking it" do
      result =
        Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, updated_at_source: :changed_on)

      assert Keyword.has_key?(result[:set], :changed_on)
    end
  end

  describe "disable precedence and field-membership admission" do
    test "updated_at_source: false omits the field despite being an explicit opt (insert)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, updated_at_source: false)

      refute Map.has_key?(result, :updated_at)
    end

    test "updated_at_source: false leaves :set untouched despite being an explicit opt (update)" do
      result = Timestamps.put_set_updated_at([set: [title: "x"]], @dt, TimestampFree, updated_at_source: false)

      refute Keyword.has_key?(result[:set], :updated_at)
    end

    test "inserted_at_source: false omits the field despite being an explicit opt (insert)" do
      result = Timestamps.put_timestamps(%{title: "x"}, @dt, TimestampFree, inserted_at_source: false)

      refute Map.has_key?(result, :inserted_at)
    end
  end
end
