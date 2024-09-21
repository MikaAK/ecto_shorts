defmodule EctoShorts.ActionsAbstractSchemaTest do
  @moduledoc false
  alias EctoShorts.Support.Schemas.UserAvatarNoConstraint
  use EctoShorts.DataCase

  alias EctoShorts.Actions
  alias EctoShorts.Support.{
    Repo,
    TestRepo
  }
  alias EctoShorts.Support.Schemas.{
    FileInfo,
    UserAvatar,
    UserAvatarNoConstraint
  }

  test "raises if repo not configured" do
    assert_raise ArgumentError, ~r|ecto shorts must be configured with a repo|, fn ->
      Actions.create({"file_info_user_avatars", FileInfo}, %{}, repo: nil)
    end
  end

  test "raises if repo not configured for replica" do
    assert_raise ArgumentError, ~r|ecto shorts must be configured with a repo|, fn ->
      Actions.all({"file_info_user_avatars", FileInfo}, %{}, repo: nil)
    end
  end

  describe "get: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert %EctoShorts.Support.Schemas.FileInfo{
        id: ^schema_data_id,
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        name: "example.txt",
        user_id: nil
      } = Actions.get({"file_info_user_avatars", FileInfo}, schema_data_id)
    end

    test "returns nil when record does not exist" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert nil === Actions.get({"file_info_user_avatars", FileInfo}, schema_data.id)
    end
  end

  describe "create: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        id: id,
        assoc_id: nil,
        name: "example.txt",
        user_id: nil
      } = schema_data

      assert schema_data === Repo.get({"file_info_user_avatars", FileInfo}, id)
    end

    test "returns changeset error" do
      assert {:error, changeset} = Actions.create({"file_info_user_avatars", FileInfo}, %{unique_identifier: "1"})

      assert {:unique_identifier, ["should be at least 3 character(s)"]} in errors_on(changeset)
    end
  end

  describe "delete: " do
    test "deletes record by id" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, deleted_schema_data} = Actions.delete({"file_info_user_avatars", FileInfo}, schema_data.id)

      assert deleted_schema_data.id === schema_data.id
    end

    test "deletes record by schema data" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, deleted_schema_data} = Actions.delete(schema_data)

      assert deleted_schema_data.id === schema_data.id
    end

    test "deletes many record by schema data" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, [deleted_schema_data]} = Actions.delete([schema_data])

      assert deleted_schema_data.id === schema_data.id
    end

    test "returns error when constraint error occurs" do
      assert {:ok, user_avatar} = Actions.create(UserAvatar, %{})

      assert {:ok, _file_info} =
        Actions.create({"file_info_user_avatars", FileInfo}, %{assoc_id: user_avatar.id})

      assert {:error, error} = Actions.delete(user_avatar)

      assert %ErrorMessage{
        code: :internal_server_error,
        details: %{changeset: changeset} = details,
        message: "Error deleting EctoShorts.Support.Schemas.UserAvatar"
      } = error

      assert %{changeset: changeset, schema_data: user_avatar} === details

      assert {:file_info, ["is still associated with this entry"]} in errors_on(changeset)
    end

    test "returns error when constraint error occurs and constraint is added with :changeset option" do
      assert {:ok, user_avatar} = Actions.create(UserAvatarNoConstraint, %{})

      assert {:ok, _file_info} =
        Actions.create({"file_info_user_avatars", FileInfo}, %{assoc_id: user_avatar.id})

      assert {:error, error} =
        Actions.delete(user_avatar, changeset: fn changeset ->
          Ecto.Changeset.no_assoc_constraint(
            changeset,
            :file_info,
            name: "file_info_user_avatars_assoc_id_fkey"
          )
        end)

      assert %ErrorMessage{
        code: :internal_server_error,
        details: %{changeset: changeset} = details,
        message: "Error deleting EctoShorts.Support.Schemas.UserAvatarNoConstraint"
      } = error

      assert %{changeset: changeset, schema_data: user_avatar} === details

      assert {:file_info, ["is still associated with this entry"]} in errors_on(changeset)
    end
  end

  describe "all: " do
    test "returns records in ascending order by default" do
      assert {:ok, schema_data_1} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, schema_data_2} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert [^schema_data_1, ^schema_data_2] = Actions.all({"file_info_user_avatars", FileInfo})
    end

    test "returns records in descending order when option :order_by is set" do
      assert {:ok, schema_data_1} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 1})

      assert {:ok, schema_data_2} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 2})

      assert [^schema_data_2, ^schema_data_1] =
        Actions.all({"file_info_user_avatars", FileInfo}, %{}, order_by: {:desc, :content_length})
    end

    test "returns records by map query parameters" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert [^schema_data] = Actions.all({"file_info_user_avatars", FileInfo}, %{id: schema_data.id})
    end

    test "returns records by keyword parameters" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert [^schema_data] = Actions.all({"file_info_user_avatars", FileInfo}, id: schema_data.id)
    end

    test "can use repo in keyword parameters" do
      TestRepo.with_shared_connection(fn ->
        assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"}, repo: TestRepo)

        assert [^schema_data] = Actions.all({"file_info_user_avatars", FileInfo}, id: schema_data.id, repo: TestRepo, replica: nil)
      end)
    end

    test "can use replica in keyword parameters" do
      TestRepo.with_shared_connection(fn ->
        assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"}, repo: TestRepo)

        assert [^schema_data] = Actions.all({"file_info_user_avatars", FileInfo}, id: schema_data.id, repo: nil, replica: TestRepo)
      end)
    end
  end

  describe "find: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, ^schema_data} = Actions.find({"file_info_user_avatars", FileInfo}, %{id: schema_data.id})
    end

    test "returns error message with params and query" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:error, error} = Actions.find({"file_info_user_avatars", FileInfo}, %{id: schema_data.id})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{id: error_id},
          query: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        message: "no records found"
      } = error

      assert error_id === schema_data.id
    end

    test "returns not found error message when params is an empty map" do
      assert {:error, error} = Actions.find({"file_info_user_avatars", FileInfo}, %{})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{},
          query: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        message: "no records found"
      } = error
    end
  end

  describe "find_or_create: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, ^schema_data} = Actions.find_or_create({"file_info_user_avatars", FileInfo}, %{id: schema_data.id})
    end

    test "creates a record if matching record not found" do
      assert {:ok, deleted_schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Actions.delete(deleted_schema_data)

      assert {:ok, schema_data} =
        Actions.find_or_create({"file_info_user_avatars", FileInfo}, %{
          id: deleted_schema_data.id,
          body: "created_record"
        })

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: id,
        name: nil,
        user_id: nil
      } = schema_data

      assert schema_data === Repo.get({"file_info_user_avatars", FileInfo}, id)
    end
  end

  describe "update: " do
    test "updates existing record by data" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, updated_schema_data} =
        Actions.update({"file_info_user_avatars", FileInfo}, schema_data, %{name: "updated_name.txt"})

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: ^schema_data_id,
        name: "updated_name.txt",
        user_id: nil
      } = updated_schema_data
    end

    test "updates existing record by ID" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, updated_schema_data} =
        Actions.update({"file_info_user_avatars", FileInfo}, schema_data.id, %{name: "updated_name.txt"})

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: ^schema_data_id,
        name: "updated_name.txt",
        user_id: nil
      } = updated_schema_data
    end

    test "updates existing record by ID and keyword list parameters" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, updated_schema_data} =
        Actions.update({"file_info_user_avatars", FileInfo}, schema_data.id, [name: "updated_name.txt"])

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: ^schema_data_id,
        name: "updated_name.txt",
        user_id: nil
      } = updated_schema_data
    end

    test "returns error when id in params does not match an existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:error, error} =
        Actions.update({"file_info_user_avatars", FileInfo}, schema_data.id, %{name: "updated_name.txt"})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          schema: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo},
          schema_id: error_id,
          updates: %{
            name: "updated_name.txt"
          }
        },
        message: error_message
      } = error

      assert error_id === schema_data.id

      assert "No item found with id: #{error_id}" === error_message
    end
  end

  describe "find_and_update: " do
    test "updates existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, updated_schema_data} =
        Actions.find_and_update(
          {"file_info_user_avatars", FileInfo},
          %{id: schema_data_id},
          %{name: "updated_name.txt"}
        )

      assert assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: ^schema_data_id,
        name: "updated_name.txt",
        user_id: nil
      } = updated_schema_data
    end

    test "returns error when params does not match an existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:error, error} =
        Actions.find_and_update(
          {"file_info_user_avatars", FileInfo},
          %{id: schema_data.id},
          %{name: "updated_name.txt"}
        )

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{id: error_id},
          query: {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}
        },
        message: "no records found"
      } = error

      assert error_id === schema_data.id
    end
  end

  describe "find_and_upsert: " do
    test "creates a record if matching record not found" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:ok, upserted_schema_data} =
        Actions.find_and_upsert(
          {"file_info_user_avatars", FileInfo},
          %{id: schema_data_id},
          %{body: "created_record"}
        )

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: returned_id,
        name: nil,
        user_id: nil
      } = upserted_schema_data

      refute schema_data === returned_id
    end

    test "updates existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      schema_data_id = schema_data.id

      assert {:ok, updated_schema_data} =
        Actions.find_and_upsert(
          {"file_info_user_avatars", FileInfo},
          %{id: schema_data_id},
          %{name: "updated_name.txt"}
        )

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        assoc_id: nil,
        id: ^schema_data_id,
        name: "updated_name.txt",
        user_id: nil
      } = updated_schema_data
    end
  end

  describe "stream: " do
    test "returns records given" do
      assert {:ok, created_schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, [returned_schema_data]} =
        Repo.transaction(fn ->
          {"file_info_user_avatars", FileInfo}
          |> Actions.stream(%{})
          |> Enum.to_list()
        end)

      assert created_schema_data.id === returned_schema_data.id
    end
  end

  describe "aggregate: " do
    test "returns expected value for aggregate count" do
      assert {:ok, _schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert 1 = Actions.aggregate({"file_info_user_avatars", FileInfo}, %{}, :count, :id)
    end

    test "returns expected value for aggregate sum" do
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 1})
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 2})

      assert 3 = Actions.aggregate({"file_info_user_avatars", FileInfo}, %{}, :sum, :content_length)
    end

    test "returns expected value for aggregate avg" do
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 2})
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 2})

      expected_decimal = Decimal.new("2.0000000000000000")

      assert ^expected_decimal = Actions.aggregate({"file_info_user_avatars", FileInfo}, %{}, :avg, :content_length)
    end

    test "returns expected value for aggregate min" do
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 1})
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 20})

      assert 1 = Actions.aggregate({"file_info_user_avatars", FileInfo}, %{}, :min, :content_length)
    end

    test "returns expected value for aggregate max" do
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 1})
      assert {:ok, _} = Actions.create({"file_info_user_avatars", FileInfo}, %{content_length: 20})

      assert 20 = Actions.aggregate({"file_info_user_avatars", FileInfo}, %{}, :max, :content_length)
    end
  end

  describe "find_or_create_many: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, [^schema_data]} =
        Actions.find_or_create_many({"file_info_user_avatars", FileInfo}, [%{id: schema_data.id}])
    end

    test "creates a record if matching record not found" do
      assert {:ok, schema_data} = Actions.create({"file_info_user_avatars", FileInfo}, %{name: "example.txt"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:ok, [schema_data]} =
        Actions.find_or_create_many(
          {"file_info_user_avatars", FileInfo},
          [
            %{
              id: schema_data.id,
              body: "created_record"
            }
          ]
        )

      assert %EctoShorts.Support.Schemas.FileInfo{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: nil,
          schema: EctoShorts.Support.Schemas.FileInfo,
          source: "file_info_user_avatars",
          state: :loaded
        },
        id: id,
        assoc_id: nil,
        name: nil,
        user_id: nil
      } = schema_data

      assert schema_data === Repo.get({"file_info_user_avatars", FileInfo}, id)
    end

    test "returns error when a constraint error occurs" do
      assert {:error, 1, changeset, changes} =
        Actions.find_or_create_many(
          {"file_info_user_avatars", FileInfo},
          [
            %{unique_identifier: "uid"},
            %{unique_identifier: "uid"}
          ]
        )

      assert %Ecto.Changeset{} = changeset

      assert {:unique_identifier, ["has already been taken"]} in errors_on(changeset)

      # check that an attempt was made to create the first record

      assert %{0 => schema_data} = changes

      assert schema_data.id
    end
  end
end
