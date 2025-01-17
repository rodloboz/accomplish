defmodule Accomplish.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :default_branch, :string, null: false
      add :git_url, :string
      add :ssh_url, :string
      add :clone_url, :string
      add :owner_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:repositories, [:name, :owner_id])
  end
end
