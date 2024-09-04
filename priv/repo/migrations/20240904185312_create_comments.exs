defmodule EctoShorts.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :body, :text
      add :count, :integer

      add :post_id, references(:posts,
        on_delete: :restrict,
        on_update: :update_all
      )

      timestamps()
    end
  end
end
