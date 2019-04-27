defmodule VM.Parser.Helpers do
  import NimbleParsec

  # Larger numbers come first.
  operator_precedence = %{
    "+": 1, "-": 1,
    "*": 2, "/": 2, "%": 2
  }

  @doc """
  Matches any whitespace sparacters.
  """
  @spec whitespace() :: NimbleParsec.t()
  def whitespace do
    repeat(
      choice( [
        string(" "),
        string("\t"),
        string("\n"),
        string("\r")
      ]))
  end

  def open_parens do
    ascii_char([ ?( ])
    |> unwrap_and_tag(:openp)
  end

  def close_parens do
    ascii_char([ ?) ])
    |> unwrap_and_tag(:closep)
  end

  @doc """
  natural_number := 0 | 1 | 2 | ...
  """
  def natural_number do
    integer(min: 1)
    |> unwrap_and_tag(:integer)
  end

  @doc """
  factor := ( expr ) | natural_number
  """

  def binary_operators do
    choice([
      string("+"),
      string("-"),
      string("/"),
      string("*"),
    ]) |> unwrap_and_tag(:binopt)
  end

  @doc """
  Converts an infix expression to a prefix tree.
  Not sure if this is possible to do within the parsec itself.
  """
  def to_prefix_tree(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [solo], [] -> solo
      [right, operator], left -> {operator, [left, right]}
      # Fail otherwise if left  operator
    end)
  end


end


defmodule VM.Parser do
  import NimbleParsec
  import VM.Parser.Helpers, only: [
    whitespace: 0,
    binary_operators: 0,
    natural_number: 0
  ]


  # factor =
  #   choice([
  #     ignore(open_parens())
  #     |> ignore(close_parens()),
  #     natural_number()
  #   ])

#   defcombinatorp :expr, choice([
#         # TODO - ignore(ascii_char([?*])) this doesn't make sense from the simplemath example, so not including it.
#     factor
#     |> concat(binary_operators())
# #    |> concat(factor)
#   ])


  defcombinatorp :binary_calc,
    ignore(whitespace())
    |> concat(natural_number())
    |> ignore(whitespace())
    |> concat(binary_operators())
    |> ignore(whitespace())
    |> concat(natural_number())



  defparsec :parse, ignore(string("=")) |> parsec(:binary_calc)

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
    {:ok, parsed, _, _, _, _} = VM.Parser.parse(value)
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
