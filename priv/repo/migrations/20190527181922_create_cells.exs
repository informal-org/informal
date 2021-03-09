defmodule Arevel.Repo.Migrations.CreateCells do
  use Ecto.Migration

  def change do
    create table(:cells) do
      add :name, :string
      add :uuid, :uuid
      add :input, :string
      add :parsed, :map
      add :output, :map
      add :dependencies, {:array, :uuid}
      add :pre_offset, :integer
      add :previous, :uuid
      add :next, :uuid

      timestamps()
    end

  end
end
