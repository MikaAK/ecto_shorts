defmodule EctoShorts.Support.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :text

      timestamps()
    end
  end
end
