defmodule EctoShorts.TypesTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Types

  describe "cast/2 with :binary_id" do
    test "dumps a UUID string to its 16-byte binary representation" do
      uuid = "f4077997-0702-4bd9-b914-9a3edc38178c"
      {:ok, expected} = Ecto.UUID.dump(uuid)

      result = Types.cast(:binary_id, uuid)

      assert expected === result
      assert 16 = byte_size(result)
    end

    test "returns the value unchanged when it is not a valid UUID" do
      assert "not-a-uuid" = Types.cast(:binary_id, "not-a-uuid")
    end

    test "returns nil unchanged" do
      assert nil === Types.cast(:binary_id, nil)
    end
  end

  describe "cast/2 with other types (regression)" do
    test "casts and dumps an integer" do
      assert 42 = Types.cast(:integer, "42")
    end

    test "returns the value unchanged for a nil type" do
      assert "unchanged" = Types.cast(nil, "unchanged")
    end
  end
end
