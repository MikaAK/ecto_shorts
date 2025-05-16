defmodule EctoShorts.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string
      add :body, :string
      add :permalink, :string
      add :published, :boolean
      add :tags, {:array, :string}
      add :views, :integer

      add :custom_string_field, :string

      add :author_id, references(:users, on_delete: :nilify_all, on_update: :update_all)

      timestamps()
    end

    create unique_index(:posts, :permalink)
  end
end
