defmodule Arevel.Cell do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cells" do
    field :dependencies, {:array, Ecto.UUID}
    field :input, :string
    field :name, :string
    field :next, Ecto.UUID
    field :output, :map
    field :parsed, :map
    field :pre_offset, :integer
    field :previous, Ecto.UUID
    field :uuid, Ecto.UUID

    timestamps()
  end

  @doc false
  def changeset(cell, attrs) do
    cell
    |> cast(attrs, [:name, :uuid, :input, :parsed, :output, :dependencies, :pre_offset, :previous, :next])
    |> validate_required([:name, :uuid, :input, :parsed])
    # |> validate_required([:name, :uuid, :input, :parsed, :output, :dependencies, :pre_offset, :previous, :next])
  end
end
