defmodule EctoShorts.Support.Schemas.Post do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  require Ecto.Query

  schema "posts" do
    field :title, :string
    field :unique_identifier, :string

    has_many :comments, EctoShorts.Support.Schemas.Comment

    has_many :authors, through: [:comments, :user]

    belongs_to :user, EctoShorts.Support.Schemas.User

    many_to_many :users, EctoShorts.Support.Schemas.User,
      join_through: EctoShorts.Support.Schemas.UserPost

    timestamps()
  end

  @available_attributes [:title, :unique_identifier, :user_id]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_attributes)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:unique_identifier)
  end

  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end

  # This callback function is invoked by `EctoShorts.CommonFilters.convert_params_to_filter`
  # when `:search` is specified in parameters.
  def by_search(query, attrs) do
    filters = Map.to_list(attrs)

    Ecto.Query.where(query, ^filters)
  end
end
