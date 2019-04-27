defmodule VM.Parser.Utils do
  @doc """
  Converts a tokenized list of symbols forming a float into a tagged
  floating point number.
  """
  def reduce_float(parts) do
    # Float.parse requires a leading zero. Convert -.3 to -0.3
    fixed_parts = case parts do
      ["-", "." | rest] ->
        ["-", "0", "." | rest]
      ["." | _] ->
        ["0" | parts]
      _ ->
        parts
    end
    {float_num, ""} = Float.parse(Enum.join(fixed_parts))
    {:float, float_num}
  end
end

defmodule VM.Parser.Helpers do
  import NimbleParsec
  import VM.Parser.Utils, only: [
    reduce_float: 1
  ]

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


  def additive_expression do
    wrap(
      ignore(whitespace())
      |> parsec(:multiplicative_expression)
      |> repeat(
        ignore(whitespace())
        |> unwrap_and_tag(choice([string("+"), string("-")]), :binopt)
        |> ignore(whitespace())
        |> parsec(:multiplicative_expression)
      )
    )
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
      [right, operator], left -> [operator, [left, right]]
      # Fail otherwise if left  operator
    end)
  end

  @doc """
  Flatten and remove unnecessary nested lists
  """
  def unwrap(acc) do
    case acc do
      [ single_elem ] ->
        unwrap(single_elem)
      [_ | _] ->
        Enum.map(acc, fn sub -> unwrap(sub) end)
      {_, _} ->
        acc
      _ ->
        acc
    end
  end

  def float_number do
    # -1.2213312e+308
    optional(string("-"))
    |> optional(integer(min: 1))
    |> string(".")
    |> integer(min: 1)
    |> optional(
      string("e+")
      |> integer(min: 1)
    )
    |> reduce({VM.Parser.Utils, :reduce_float, []})
    #|> reduce({Enum, :join, [""]})
    #|> map({Float, :parse, []})
  end



end


defmodule VM.Parser do
  import NimbleParsec
  import VM.Parser.Helpers, only: [
    whitespace: 0,
    natural_number: 0,
    float_number: 0,
    open_parens: 0,
    close_parens: 0,
    additive_expression: 0,
    unwrap: 1
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

  # defcombinatorp :expression,
  #   :equalityexpr

  # https://en.wikipedia.org/wiki/Operator-precedence_parser#section=2
  # Precedence climbing method (* repeat)
  # expression ::= equality-expression
  # equality-expression ::= additive-expression ( ( '==' | '!=' ) additive-expression ) *
  # additive-expression ::= multiplicative-expression ( ( '+' | '-' ) multiplicative-expression ) *
  # multiplicative-expression ::= primary ( ( '*' | '/' ) primary ) *

  defcombinatorp :multiplicative_expression,
    wrap(
      ignore(whitespace())
      |> parsec(:primary_expression)
      |> repeat(
        ignore(whitespace())
        |> unwrap_and_tag(choice([string("*"), string("/")]), :binopt)
        |> ignore(whitespace())
        |> parsec(:primary_expression)
      )
    )

  # TODO: Variables, test unary negative, floating point, whitespace support
  # primary ::= '(' expression ')' | NUMBER | VARIABLE | '-' primary
  defcombinatorp :primary_expression,
    choice([
      wrap(
        ignore(open_parens())
        |> ignore(whitespace())
        |> parsec(:expression)
        |> ignore(whitespace())
        |> ignore(close_parens())
      ),
      float_number(),
      natural_number(),
      string("-") |> parsec(:primary_expression)
    ])

  # This whole thing could probably be implemented more efficiently with lookahead, but keeping it "simple" for now
  defcombinatorp :expression,
    additive_expression()

  # defparsec :parse, ignore(string("=")) |> parsec(:binary_calc)
  defparsec :parse, ignore(string("=")) |> parsec(:expression)

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

  def eval_expr(expr) do
    # %{id: id, value: value} = cell
    # TODO: case value starts with =
    {:ok, parsed, "", _, _, _} = VM.Parser.parse(expr)
    recurse_expr(parsed)
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
