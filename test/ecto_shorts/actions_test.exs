defmodule EctoShorts.ActionsTest do
  @moduledoc false
  use EctoShorts.DataCase

  alias EctoShorts.Actions
  alias EctoShorts.Support.{
    Repo,
    TestRepo
  }
  alias EctoShorts.Support.Schemas.{
    Comment,
    Post
  }
  alias EctoShorts.Support.Contexts.Posts

  test "raise when :repo not set in option and configuration" do
    assert_raise ArgumentError, ~r|EctoShorts repo not configured!|, fn ->
      Actions.create(Comment, %{}, repo: nil)
    end
  end

  test "raise when :repo and :replica not set in option and configuration" do
    assert_raise ArgumentError, ~r|EctoShorts replica and repo not configured!|, fn ->
      Actions.all(Comment, %{}, repo: nil, replica: nil)
    end
  end

  describe "get: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      schema_data_id = schema_data.id

      assert %Comment{id: ^schema_data_id} = Actions.get(Comment, schema_data_id)
    end

    test "returns nil when record does not exist" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert nil === Actions.get(Comment, schema_data.id)
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

    test "deletes many records by changeset" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      changeset = Comment.changeset(schema_data, %{})

      assert {:ok, [deleted_schema_data]} = Actions.delete([changeset])

      assert deleted_schema_data.id === schema_data.id
    end

    test "deletes many record by schema data" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [deleted_schema_data]} = Actions.delete([schema_data])

      assert deleted_schema_data.id === schema_data.id
    end

    test "returns error when given a changeset and a constraint error occurs" do
      assert {:ok, post_schema_data} = Actions.create(Post, %{title: "title"})

      assert {:ok, _comment_schema_data} =
        Actions.create(
          Comment,
          %{
            body: "body",
            post_id: post_schema_data.id
          }
        )

      assert {:error, error} =
        post_schema_data
        |> Post.changeset(%{})
        |> Actions.delete()

      assert %ErrorMessage{
        code: :internal_server_error,
        details: %{changeset: changeset},
        message: "Error deleting EctoShorts.Support.Schemas.Post"
      } = error

      assert %Ecto.Changeset{} = changeset

      assert {:comments, ["are still associated with this entry"]} in errors_on(changeset)
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

    test "returns records by map query parameters" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert [^schema_data] = Actions.all(Comment, %{id: schema_data.id})
    end

    test "returns data by map query parameters with custom filter and query builder in options" do
      assert {:ok, %Comment{id: id, body: body}} = Actions.create(Comment, %{body: "body"})

      assert [^body] = Actions.all(Comment, %{id: id, select_body: true}, query_builder: Posts)
      assert [^body] = Actions.all({"comments", Comment}, %{id: id, select_body: true}, query_builder: Posts)
    end

    test "returns records by keyword parameters" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert [^schema_data] = Actions.all(Comment, id: schema_data.id)
    end

    test "can use repo in keyword parameters" do
      TestRepo.with_shared_connection(fn ->
        assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"}, repo: TestRepo)

        assert [^schema_data] = Actions.all(Comment, id: schema_data.id, repo: TestRepo, replica: nil)
      end)
    end

    test "can use replica in keyword parameters" do
      TestRepo.with_shared_connection(fn ->
        assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"}, repo: TestRepo)

        assert [^schema_data] = Actions.all(Comment, id: schema_data.id, repo: nil, replica: TestRepo)
      end)
    end

    test "can use custom filters and query_builder in keyword parameters" do
      assert {:ok, %Comment{id: id, body: body}} = Actions.create(Comment, %{body: "body"})

      assert [^body] = Actions.all(Comment, id: id, select_body: true, query_builder: Posts)
    end
  end

  describe "find: " do
    test "returns record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, ^schema_data} = Actions.find(Comment, %{id: schema_data.id})
    end

    test "returns data with custom filters and query_builder in keyword parameters" do
      assert {:ok, %Comment{id: id, body: body}} = Actions.create(Comment, %{body: "body"})

      assert {:ok, ^body} = Actions.find(Comment, %{id: id, select_body: true}, query_builder: Posts)
    end

    test "returns error message with params and query" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Repo.delete(schema_data)

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

    test "returns not found error message when params is an empty map" do
      assert {:error, error} = Actions.find(Comment, %{})

      assert %ErrorMessage{
        code: :not_found,
        details: %{
          params: %{},
          query: EctoShorts.Support.Schemas.Comment
        },
        message: "no records found"
      } = error
    end
  end

  describe "find_or_create: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, ^schema_data} = Actions.find_or_create(Comment, %{id: schema_data.id})
    end

    test "creates a record if matching record not found" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Repo.delete(schema_data)

      assert {:ok, created_schema_data} =
        Actions.find_or_create(Comment, %{
          id: schema_data.id,
          body: "created_record"
        })

      assert %{body: "created_record"} = created_schema_data

      refute schema_data.id === created_schema_data.id
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

      assert {:ok, _} = Repo.delete(schema_data)

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

  describe "find_and_upsert: " do
    test "creates a record if matching record not found" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Repo.delete(schema_data)

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
    test "returns records given" do
      assert {:ok, created_schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [returned_schema_data]} =
        Repo.transaction(fn ->
          Comment
          |> Actions.stream(%{})
          |> Enum.to_list()
        end)

      assert created_schema_data.id === returned_schema_data.id
    end

    test "returns data according to custom filter" do
      assert {:ok, created_schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [returned_schema_data]} =
               Repo.transaction(fn ->
                 Comment
                 |> Actions.stream(%{select_body: true}, query_builder: Posts)
                 |> Enum.to_list()
               end)

      assert created_schema_data.body === returned_schema_data
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

    test "returns expected value for aggregate count using custom filter" do
      assert {:ok, post_schema_data_1} = Actions.create(Post, %{title: "title"})
      assert {:ok, post_schema_data_2} = Actions.create(Post, %{title: "title"})
      assert {:ok, _schema_data} = Actions.create(Comment, %{post_id: post_schema_data_1.id})
      assert {:ok, _schema_data} = Actions.create(Comment, %{post_id: post_schema_data_2.id})
      assert {:ok, _schema_data} = Actions.create(Comment, %{post_id: post_schema_data_2.id})

      assert 1 =
        Actions.aggregate(Comment, %{post_id_with_comment_count_gte: 2}, :count, :post_id, query_builder: Posts)
    end
  end

  describe "find_or_create_many: " do
    test "returns existing record" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, [^schema_data]} =
        Actions.find_or_create_many(Comment, [%{id: schema_data.id}])
    end

    test "creates a record if matching record not found" do
      assert {:ok, schema_data} = Actions.create(Comment, %{body: "body"})

      assert {:ok, _} = Repo.delete(schema_data)

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
