defmodule EctoShorts.Repo.Migrations.CreatePostsWithLock do
  use Ecto.Migration

  def change do
    create table(:posts_with_lock) do
      add :title, :string
      add :lock_version, :integer, default: 1

      timestamps()
    end
  end
end
