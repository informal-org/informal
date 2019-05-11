defmodule VM do
  @doc """
  Evaluate an expression json tree.
  """
  def eval(code) do
    %{body: body} = code

    result = Enum.map(body, fn cell -> eval_expr(cell) end)
    # TODO - :ok check
    # elem(result, 1)
    IO.puts result
    result
  end

  def eval_expr(expr) do
    # %{id: id, value: value} = cell
    # TODO: case value starts with =
    recurse_expr(expr)
  end

  # [integer: 11, operator: "/", integer: 13]
  def binary_operator([integer: a, operator: "/", integer: b]) do
    a / b
  end

  def binary_operator([integer: a, operator: "+", integer: b]) do
    a + b
  end

  def binary_operator(left, op, right) do
    case op do
      "+" ->
        left + right
      "-" ->
        left - right
      "*" ->
        left * right
      "/" ->
        left / right
    end
  end

  # [integer: 1], {:binopt, "+"}, [integer: 2, binopt: "*", integer: 3]
  def recurse_expr(expr) do
    case expr do
      # Unwrap empty wrapper
      [ single_elem ] ->
        recurse_expr(single_elem)
      [left, {:binopt, op}, right] ->
        binary_operator(recurse_expr(left), op, recurse_expr(right))
      {:integer, i} ->
        i
      {:float, i} ->
        i
      # [_ | _] ->
      #   # Enumerate over items. Left first.
      #   Enum.map(expr, fn sub -> recurse_expr(sub) end)
      # {_, _} ->
      #   acc
      # _ ->
      #   acc
    end

  end

  def get_dependencies() do
      # TODO
  end
end
