defmodule EctoShorts.Repo.Migrations.CreatePostsAuthorsTable do
  use Ecto.Migration

  def change do
    create table(:posts_authors) do
      add :author_id, references(:users, on_delete: :delete_all, on_update: :update_all)
      add :post_id, references(:posts, on_delete: :delete_all, on_update: :update_all)

      timestamps()
    end

    create unique_index(:posts_authors, [:author_id, :post_id])
  end
end
