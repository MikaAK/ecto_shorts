defmodule EctoShorts.ActionsTest do
  @moduledoc false
  use EctoShorts.DataCase

  alias EctoShorts.Actions
  alias EctoShorts.Support.Schemas.{
    Comment,
    Post
  }

  test "raises if repo not configured" do
    assert_raise ArgumentError, ~r|ecto shorts must be configured with a repo|, fn ->
      Actions.create(Comment, %{}, repo: nil)
    end
  end

  test "raises if repo not configured for replica" do
    assert_raise ArgumentError, ~r|ecto shorts must be configured with a repo|, fn ->
      Actions.all(Comment, %{}, repo: nil)
    end
  end

  describe "create: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert %Comment{} = schema_data
    end

    test "returns changeset error" do
      assert {:error, changeset} = Actions.create(Comment, %{body: "1"})

      assert {:body, ["should be at least 3 character(s)"]} in errors_on(changeset)
    end
  end

  describe "delete: " do
    test "deletes record by id" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, deleted_schema_data} = Actions.delete(Comment, schema_data.id)

      assert deleted_schema_data.id === schema_data.id
    end

    test "deletes record by schema data" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, deleted_schema_data} = Actions.delete(schema_data)

      assert deleted_schema_data.id === schema_data.id
    end

    test "deletes many record by schema data" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [deleted_schema_data]} = Actions.delete([schema_data])

      assert deleted_schema_data.id === schema_data.id
    end

    test "returns error when delete fails due to a constraint delete" do
      assert {:ok, post_schema_data} = Actions.create(Post, %{title: "title"})

      assert {:ok, _comment_schema_data} =
        Actions.create(
          Comment,
          %{
            body: "body",
            post_id: post_schema_data.id
          }
        )

      assert {:error, error} = Actions.delete(post_schema_data)

      assert %ErrorMessage{
        code: :internal_server_error,
        details: %{
          changeset: changeset,
          schema_data: schema_data
        },
        message: "Error deleting EctoShorts.Support.Schemas.Post"
      } = error

      assert %Ecto.Changeset{} = changeset

      assert {:comments, ["are still associated with this entry"]} in errors_on(changeset)

      assert schema_data === post_schema_data
    end
  end

  describe "all: " do
    test "returns records in ascending order by default" do
      assert {:ok, schema_data_1} = Actions.create(Comment, %{body: "body"})

      assert {:ok, schema_data_2} = Actions.create(Comment, %{body: "body"})

      assert [^schema_data_1, ^schema_data_2] = Actions.all(Comment)
    end

    test "returns records in descending order when option :order_by is set" do
      assert {:ok, schema_data_1} = Actions.create(Comment, %{count: 1})

      assert {:ok, schema_data_2} = Actions.create(Comment, %{count: 2})

      assert [^schema_data_2, ^schema_data_1] = Actions.all(Comment, %{}, order_by: {:desc, :count})
    end

    test "returns records by query parameters" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert [^schema_data] = Actions.all(Comment, %{id: schema_data.id})
    end

    test "returns records when parameters is a keyword list" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert [^schema_data] = Actions.all(Comment, id: schema_data.id)
    end
  end

  describe "find: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, ^schema_data} = Actions.find(Comment, %{id: schema_data.id})
    end

    test "returns error message with params and query" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:error, error} = Actions.find(Comment, %{id: schema_data.id})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{id: error_id},
          query: EctoShorts.Support.Schemas.Comment
        },
        message: "no records found"
      } = error

      assert error_id === schema_data.id
    end
  end

  describe "find_or_create: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, ^schema_data} = Actions.find_or_create(Comment, %{id: schema_data.id})
    end

    test "creates a record if the id in params doesn't match an existing record." do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:ok, schema_data} =
        Actions.find_or_create(Comment, %{
          id: schema_data.id,
          body: "created_record"
        })

      assert %{body: "created_record"} = schema_data
    end
  end

  describe "update: " do
    test "updates existing record by data" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, updated_schema_data} = Actions.update(Comment, schema_data, %{body: "updated_body"})

      assert %{body: "updated_body"} = updated_schema_data
    end

    test "updates existing record by ID" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, updated_schema_data} =
        Actions.update(Comment, schema_data.id, %{body: "updated_body"})

      assert %{body: "updated_body"} = updated_schema_data
    end

    test "updates existing record by ID and keyword list parameters" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, updated_schema_data} =
        Actions.update(Comment, schema_data.id, [body: "updated_body"])

      assert %{body: "updated_body"} = updated_schema_data
    end

    test "returns error when id in params does not match an existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:error, error} =
        Actions.update(Comment, schema_data.id, %{body: "updated_body"})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          schema: EctoShorts.Support.Schemas.Comment,
          schema_id: error_id,
          updates: %{
            body: "updated_body"
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
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, updated_schema_data} =
        Actions.find_and_update(
          Comment,
          %{id: schema_data.id},
          %{body: "updated_body"}
        )

      assert %{body: "updated_body"} = updated_schema_data
    end

    test "returns error when params does not match an existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:error, error} =
        Actions.find_and_update(
          Comment,
          %{id: schema_data.id},
          %{body: "updated_body"}
        )

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{id: error_id},
          query: EctoShorts.Support.Schemas.Comment
        },
        message: "no records found"
      } = error

      assert error_id === schema_data.id
    end
  end

  describe "find_and_upsert: " do
    test "creates a record if the id in params doesn't match an existing record." do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:ok, schema_data} =
        Actions.find_and_upsert(
          Comment,
          %{id: schema_data.id},
          %{body: "created_record"}
        )

      assert %{body: "created_record"} = schema_data
    end

    test "updates existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, updated_schema_data} =
        Actions.find_and_upsert(
          Comment,
          %{id: schema_data.id},
          %{body: "updated_body"}
        )

      assert %{body: "updated_body"} = updated_schema_data
    end
  end

  describe "stream: " do
    test "returns records" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [^schema_data]} =
        EctoShorts.Config.repo().transaction(fn ->
          Comment
          |> Actions.stream(%{})
          |> Enum.to_list()
        end)
    end
  end

  describe "aggregate: " do
    test "returns expected value for aggregate count" do
      assert {:ok, _schema_data} = Actions.create(Comment, %{body: "body"})

      assert 1 = Actions.aggregate(Comment, %{}, :count, :id)
    end

    test "returns expected value for aggregate sum" do
      assert {:ok, _} = Actions.create(Comment, %{count: 1})
      assert {:ok, _} = Actions.create(Comment, %{count: 2})

      assert 3 = Actions.aggregate(Comment, %{}, :sum, :count)
    end

    test "returns expected value for aggregate avg" do
      assert {:ok, _} = Actions.create(Comment, %{count: 2})
      assert {:ok, _} = Actions.create(Comment, %{count: 2})

      expected_decimal = Decimal.new("2.0000000000000000")

      assert ^expected_decimal = Actions.aggregate(Comment, %{}, :avg, :count)
    end

    test "returns expected value for aggregate min" do
      assert {:ok, _} = Actions.create(Comment, %{count: 1})
      assert {:ok, _} = Actions.create(Comment, %{count: 20})

      assert 1 = Actions.aggregate(Comment, %{}, :min, :count)
    end

    test "returns expected value for aggregate max" do
      assert {:ok, _} = Actions.create(Comment, %{count: 1})
      assert {:ok, _} = Actions.create(Comment, %{count: 20})

      assert 20 = Actions.aggregate(Comment, %{}, :max, :count)
    end
  end

  describe "find_or_create_many: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [^schema_data]} =
        Actions.find_or_create_many(Comment, [%{id: schema_data.id}])
    end

    test "creates a record if the id in params doesn't match an existing record." do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Actions.delete(schema_data)

      assert {:ok, list_of_schema_data} =
        Actions.find_or_create_many(
          Comment,
          [
            %{
              id: schema_data.id,
              body: "created_record"
            }
          ]
        )

      assert [%{body: "created_record"}] = list_of_schema_data
    end

    test "returns error when a constraint error occurs" do
      assert {:error, 1, changeset, changes} =
        Actions.find_or_create_many(
          Post,
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
