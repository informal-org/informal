
defmodule Arevel.Utils do

  # https://stackoverflow.com/a/44278017
  def invert_map(map) do
    Enum.reduce(map, %{}, fn {k, vs}, acc ->
      Enum.reduce(vs, acc, fn v, acc ->
        with {_, map} <- Map.get_and_update(acc, v, fn
          nil -> {nil, MapSet.new([k])}
          set -> {set, MapSet.put(set, k)}
        end), do: map
      end)
    end)
  end

end
