defmodule EctoShorts.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :age, :integer
      add :first_name, :string
      add :last_name, :string

      timestamps()
    end
  end
end
