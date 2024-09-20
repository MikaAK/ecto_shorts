defmodule EctoShorts.Support.Repo.Migrations.CreateUsersPosts do
  use Ecto.Migration

  def change do
    create table(:users_posts) do
      add :post_id, references(:posts,
        on_delete: :delete_all,
        on_update: :update_all
      )

      add :user_id, references(:users,
        on_delete: :delete_all,
        on_update: :update_all
      )

      timestamps()
    end
  end
end
