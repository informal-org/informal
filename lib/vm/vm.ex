defmodule VM.Math do
  def add(a, b) do
    a + b
  end

  def subtract(a, b) do
    a - b
  end

  def multiply(a, b) do
    a * b
  end

  def divide(a, b) do
    a / b
  end

  def modulo(a, b) do
    rem(a, b)
  end

  def negative(a) do
    a * -1
  end

end

defmodule VM.Bool do
  def bool_and(a, b) do
    a && b
  end

  def bool_or(a, b) do
    a || b
  end

  def bool_not(a) do
    !a
  end
  def bool_is(a, b) do
    a == b
  end

  # Not sure if these should be classified as boolean or math operators.
  def bool_gt(a, b) do
    a > b
  end

  def bool_lt(a, b) do
    a < b
  end

  def bool_gte(a, b) do
    a >= b
  end

  def bool_lte(a, b) do
    a <= b
  end

end


defmodule VM do
  import VM.Math
  import Arevel.Utils

  def binary_operators, do: %{
    "+" => &VM.Math.add/2,
    "-" => &VM.Math.subtract/2,
    "*" => &VM.Math.multiply/2,
    "/" => &VM.Math.divide/2,
    "MOD" => &VM.Math.modulo/2,

    # Boolean operators
    "AND" => &VM.Bool.bool_and/2,
    "OR" => &VM.Bool.bool_or/2,
    "IS" => &VM.Bool.bool_is/2,
    # XOR? Keep it minimal for now.

    # Comparison operators
    "<" => &VM.Bool.bool_lt/2,
    "<=" => &VM.Bool.bool_lte/2,
    ">" => &VM.Bool.bool_gt/2,
    ">=" => &VM.Bool.bool_gte/2,
  }

  def unary_operators, do: %{
    "-" => &VM.Math.negative/1,
    "NOT" => &VM.Bool.bool_not/1,
  }

  @doc """
  Evaluate an expression json tree.
  """
  def eval(code) do
    {status, order} = get_eval_order(code)
    # TODO handle error case
    {_, result} = Enum.map_reduce(
      order,
      code,
      fn (id, acc) -> eval_cell(Map.get(acc, id), acc) end
    )
    IO.inspect(result)
    # Convert tuple back into map
    # Enum.into(result, %{})
    result
  end

  def eval_cell(cell, cells) do
    %{"id" => id, "parsed" => parsed} = cell
    out = eval_expr(parsed, cells)
    cell = Map.put(cell, "output", out)
    cells = Map.put(cells, id, cell)
    {cell, cells}
  end

  def eval_expr(expr, cells) do
    # %{id: id, value: value} = cell
    # TODO: case value starts with =
    recurse_expr(expr, cells)
  end

  def eval_binary(op, left, right) do
    op = String.upcase(op)
    Map.get(VM.binary_operators, op).(left, right)
  end

  def eval_unary(op, arg) do
    op = String.upcase(op)
    Map.get(VM.unary_operators, op).(arg)
  end

  # [integer: 1], {:binopt, "+"}, [integer: 2, binopt: "*", integer: 3]
  def recurse_expr(expr, cells) do
    case Map.get(expr, "type") do
      # Unwrap empty wrapper
      "BinaryExpression" ->
        op = Map.get(expr, "operator")
        left = recurse_expr(Map.get(expr, "left"), cells)
        right = recurse_expr(Map.get(expr, "right"), cells)
        eval_binary(op, left, right)
      "UnaryExpression" ->
        op = Map.get(expr, "operator")
        arg = recurse_expr(Map.get(expr, "argument"), cells)
        eval_unary(op, arg)
      "Literal" ->
        Map.get(expr, "value")
      "Identifier" ->
        ref = Map.get(cells, Map.get(expr, "name"))
        # Does it always reference the output value or should it ref the cell?
        Map.get(ref, "output")
    end
  end

  @doc """
  Performs a topological sort over a dependency map in the form [{"id01", []}, {"id02", ["id01"]}]
  returns a tuple of :ok, [path of ids] or :cycle, [cyclical IDs]
  """
  def get_eval_order(cells) do
    graph = get_dependency_graph(cells)
    if path = :digraph_utils.topsort(graph) do
      print_path(path)
      {:ok, path}
    else
      cyclic_cells = Enum.filter(:digraph.vertices(graph), fn cell -> :digraph.get_short_cycle(graph,cell) end)
      {:cycle, cyclic_cells}
    end
  end

  def get_dependency_graph(cells) do
    dependency_map = Enum.map(cells, fn {id, cell} -> {id, Map.get(cell, "depends_on")} end)
    graph = :digraph.new
    Enum.each(dependency_map, fn {cell,deps} ->
      :digraph.add_vertex(graph,cell)
      Enum.each(deps, fn dep -> add_dependency(graph,cell,dep) end)
    end)
    graph
  end

  defp print_path(l), do: IO.puts Enum.join(l, " -> ")

  def add_dependency(_graph,cell,cell), do: :ok   # Skip adding dependencies to self.
  def add_dependency(graph,cell,dependency) do
    :digraph.add_vertex(graph,dependency)         # No-op if it already exists.
    :digraph.add_edge(graph,dependency,cell)      # Dependencies represented as an edge d -> l
  end

  # def get_eval_order(leafs, dependency_map) do
  #   [cell | _] = leafs

  #   # Enum.concat([cell], )
  # end


end


