defmodule VM.Parser.Helpers do
  import NimbleParsec

  def whitespace do
    repeat(string(" "))
  end

  def number do
    integer(min: 1)
    |> unwrap_and_tag(:integer)
  end

  def numerical_operators do
    choice([
      string("+"),
      string("-"),
      string("/"),
      string("*"),
    ]) |> unwrap_and_tag(:operator)
  end

  def bi_calc do
    ignore(string("="))
    |> ignore(whitespace())
    |> concat(number())
    |> ignore(whitespace())
    |> concat(numerical_operators())
    |> ignore(whitespace())
    |> concat(number())
  end

end


defmodule VM.Parser do
  import NimbleParsec
  import VM.Parser.Helpers

  defparsec :expression, VM.Parser.Helpers.bi_calc()

  # defparsec :datetime, whitespace |> ignore(string("T")) |> concat(time)

end


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
