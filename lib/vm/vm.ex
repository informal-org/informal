
defmodule VM.Parser do
  import NimbleParsec

  whitespace = repeat(string(" "))

  number =
    integer(min: 1)
    |> unwrap_and_tag(:integer)

  numerical_operators =
    choice([
      string("+"),
      string("-"),
      string("/"),
      string("*"),
    ]) |> unwrap_and_tag(:operator)

  bi_calc =
    ignore(string("="))
    |> ignore(whitespace)
    |> concat(number)
    |> ignore(whitespace)
    |> concat(numerical_operators)
    |> ignore(whitespace)
    |> concat(number)

  defparsec :expression, bi_calc

  # defparsec :datetime, whitespace |> ignore(string("T")) |> concat(time)

end


defmodule VM do
  @doc """
  Evaluate an expression json tree.
  """
  def eval(code) do
    %{body: body} = code

    Enum.map(body, fn cell -> eval_expr(cell) end)
  end

  def eval_expr(cell) do
    %{id: id, value: value} = cell
    # TODO: case value starts with =
    {:ok, parsed, _, _, _, _} = VM.Parser.expression(value)
    binary_operator(parsed)
  end

  # [integer: 11, operator: "/", integer: 13]
  def binary_operator([integer: a, operator: "/", integer: b]) do
    a / b
  end

  def binary_operator([integer: a, operator: "+", integer: b]) do
    a + b
  end

  def get_dependencies() do
      # TODO
  end
end
