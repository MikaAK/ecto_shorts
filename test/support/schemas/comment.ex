defmodule EctoShorts.Support.Schemas.Comment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  require Ecto.Query

  schema "comments" do
    field :body, :string
    field :count, :integer
    field :tags, {:array, :string}

    belongs_to :post, EctoShorts.Support.Schemas.Post

    belongs_to :user, EctoShorts.Support.Schemas.User

    timestamps()
  end

  @available_fields [:body, :count, :post_id, :user_id]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> validate_length(:body, min: 3)
  end

  def select_body(queryable \\ __MODULE__),
    do: Ecto.Query.select(queryable, [c], c.body)

  def post_id_with_comment_count_gte(queryable \\ __MODULE__, count) do
    queryable
    |> Ecto.Query.group_by([c], c.post_id)
    |> Ecto.Query.select([c], c.post_id)
    |> Ecto.Query.having([c], count(c.post_id) >= ^count)
    |> Ecto.Query.subquery()
  end
end
