defmodule EctoShorts.Support.Schemas.FileInfo do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  require Ecto.Query

  schema "abstract table: file_infos" do
    field :assoc_id, :integer
    field :name, :string
    field :content_length, :integer
    field :unique_identifier, :string

    belongs_to :user, EctoShorts.Support.Schemas.User

    timestamps()
  end

  @available_fields [
    :name,
    :content_length,
    :unique_identifier,
    :assoc_id,
    :user_id
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> unique_constraint(:unique_identifier)
    |> validate_length(:unique_identifier, min: 3)
  end

  # This callback function is invoked by `EctoShorts.CommonFilters.convert_params_to_filter`
  # when `:search` is specified in parameters.
  def by_search(query, attrs) do
    filters = Map.to_list(attrs)

    Ecto.Query.where(query, ^filters)
  end
end
