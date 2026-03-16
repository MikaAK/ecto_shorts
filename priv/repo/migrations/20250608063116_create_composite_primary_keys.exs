defmodule EctoShorts.Repo.Migrations.CreateCompositePrimaryKeys do
  use Ecto.Migration

  def change do
    create table(:composite_primary_keys) do
      add :comment_id, references(:comments, on_update: :update_all), primary_key: true
      add :post_id, references(:posts, on_update: :update_all), primary_key: true
      add :role, :string

      timestamps()
    end
  end
end
