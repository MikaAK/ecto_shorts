defmodule EctoShorts.Schemas.Post do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Query
  require Ecto.Query

  schema "posts" do
    belongs_to :author, EctoShorts.Schemas.User

    many_to_many :authors, EctoShorts.Schemas.User,
      join_through: EctoShorts.Schemas.PostAuthor,
      join_keys: [post_id: :id, author_id: :id],
      unique: true

    has_many :comments, EctoShorts.Schemas.Comment

    has_many :comments_authors, through: [:comments, :author]

    field :title, :string
    field :body, :string
    field :published, :boolean
    field :notes, :string, source: :custom_string_field
    field :tags, {:array, :string}
    field :views, :integer
    field :permalink, :string

    timestamps()
  end

  @required_fields []
  @available_fields [
                      :author_id,
                      :body,
                      :notes,
                      :permalink,
                      :published,
                      :tags,
                      :title,
                      :views
                    ] ++ @required_fields

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:author_id)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:permalink)
  end

  def create_changeset({source, params}) do
    %__MODULE__{}
    |> Ecto.put_meta(source: source)
    |> changeset(params)
  end

  def create_changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  # This callback function is invoked by `EctoShorts.CommonFilters.convert_params_to_filter`
  # when `:search` is specified in parameters.
  def by_search(query, attrs) do
    Query.where(query, ^Map.to_list(attrs))
  end
end
