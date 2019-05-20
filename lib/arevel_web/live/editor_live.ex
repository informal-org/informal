defmodule ArevelWeb.EditorLive do
  use Phoenix.LiveView
  alias ArevelWeb.EditorView

  # def render(assigns) do
  #   ArevelWeb.PageView.render("index.html", assigns)
  # end

  # def mount(%{expression: expression}, socket) do
  #   # case Thermostat.get_user_reading(user_id, id) do
  #   #   {:ok, temperature} ->
  #   #     {:ok, assign(socket, :temperature, temperature)}
  #   #   {:error, reason} ->
  #   #     {:error, reason}

  #   {:ok, assign(socket, :expression, expression)}
  # end

  def render(assigns) do
    EditorView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    socket = assign(socket, :expression, "1 + 1")
    socket = assign(socket, :result, nil)

    # TODO: Terminology
    # Module?
    # body: Cells
    # raw: input. parsed. output.
    # name
    # id
    # Other metadata at the direct level.
    module = %{
      "name" => "Hello world",
      "cells" => [
         %{
          "id" => 1,
          "name" => "cell1",
          "input" => "1 + 1",
          "output" => nil
          # Parsed. Result.
        }
      ]
    }

    # Cells as a list doesn't make sense.
    # It's ordered, but poor lookup.
    # Also I think the assigns mechanism will make it clone and
    # re-send everything on every diff.
    # I need a more incremental structure.
    # These are temporary problems because the code is in memory rather than in the db.

    socket = assign(socket, :module, module)

    {:ok, socket}
  end


  def handle_event("validate", _, socket) do
    IO.puts("Validating")

    {:noreply, socket}
  end


  def handle_event("evaluate", input, socket) do
    IO.puts("Evaluating")
    %{"id" => id, "input" => expr, "parsed" => parsed} = input
    {:ok, parsed_json} = Jason.decode(parsed)
    IO.puts(parsed)
    result = VM.recurse_expr(parsed_json)

    module = Map.get(socket.assigns, :module)
    cells = Map.get(module, "cells")

    # TODO - filter and search by ID to find the right element
    cell = List.first(cells)
    cell = Map.put(cell, "input", expr)

    module = Map.put(module, "cells", [
      cell
    ])


    # socket = assign(socket, :expression, expr)
    # socket = assign(socket, :result, result)
    socket = assign(socket, :module, module)

    {:noreply, socket}
  end



end


