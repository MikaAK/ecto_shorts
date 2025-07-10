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
      unique: true,
      on_replace: :delete

    has_many :comments, EctoShorts.Schemas.Comment, on_replace: :delete
    has_many :comments_authors, through: [:comments, :author]

    has_many :composite_primary_keys, EctoShorts.Schemas.CompositePrimaryKey

    field :body, :string
    field :notes, :string, source: :custom_string_field
    field :permalink, :string
    field :published_at, :utc_datetime
    field :published, :boolean
    field :title, :string
    field :tags, {:array, :string}
    field :views, :integer

    timestamps()
  end

  @required_fields []
  @available_fields [
                      :author_id,
                      :body,
                      :notes,
                      :permalink,
                      :published,
                      :published_at,
                      :tags,
                      :title,
                      :views
                    ] ++ @required_fields

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    schema_data_or_changeset
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
