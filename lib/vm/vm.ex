defmodule VM.Parser.Utils do

  @doc ~S"""
  Converts a tokenized list of symbols forming a float into a tagged
  floating point number.

      iex> VM.Parser.Utils.reduce_float(["3", ".", "14159265359"])
      {:float, 3.14159265359}

      iex> VM.Parser.Utils.reduce_float(["-", "2", ".", "71828"])
      {:float, -2.71828}

      iex> VM.Parser.Utils.reduce_float([".", "27"])
      {:float, 0.27}

      iex> VM.Parser.Utils.reduce_float([".", "9", "e+", "3"])
      {:float, 900.0}

      iex> VM.Parser.Utils.reduce_float(["1", ".", "0", "e", "+", "10"])
      {:float, 1.0e10}

      iex> VM.Parser.Utils.reduce_float(["1", ".", "0", "e", "-", "10"])
      {:float, 1.0e-10}
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


  @doc ~S"""
  Unwraps, tags and applies unary negative to tokenized integers.
      iex> VM.Parser.Utils.reduce_int([9])
      {:integer, 9}

      iex> VM.Parser.Utils.reduce_int(["-", 27])
      {:integer, -27}

      iex> VM.Parser.Utils.reduce_int(["-", 0])
      {:integer, 0}
  """
  def reduce_int(parts) do
    fixed_int = case parts do
      ["-" | [num]] ->
        -1 * num
      [num] ->
        num
    end
    {:integer, fixed_int}
  end

end

defmodule VM.Parser.Boolean do
  import NimbleParsec

  def bool_true do
    choice([
      string("true"),
      string("TRUE"),
      string("True"),
    ])
    |> replace(true) |> label("true")
  end

  def bool_false do
    choice([
      string("false"),
      string("FALSE"),
      string("False"),
    ])
    |> replace(false) |> label("false")
  end

  def boolean_literal do
    choice([
        bool_true(),
        bool_false()
    ]) |> label("boolean")
  end

  def operator_not do
    choice([
      string("not"),
      string("NOT"),
      string("Not")
    ])
    |> replace(:op_not) |> label("not")
  end

  def operator_and do
    choice([
      string("and"),
      string("AND"),
      string("And")
    ])
    |> replace(:op_and) |> label("and")
  end

  def operator_or do
    choice([
      string("or"),
      string("OR"),
      string("Or")
    ])
    |> replace(:op_or) |> label("or")
  end

  def operator_is do
    choice([
      string("is"),
      string("IS"),
      string("Is"),
    ])
    |> replace(:op_is) |> label("is")
  end

end

defmodule VM.Parser.Helpers do
  import NimbleParsec
  import VM.Parser.Utils, only: [
    reduce_float: 1,
    reduce_int: 1
  ]

  import VM.Parser.Boolean, only: [
    operator_or: 0,
    operator_and: 0,
    operator_not: 0,
    operator_is: 0,
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


  @doc """
  natural_number := 0 | 1 | 2 | ...
  """
  def natural_number do
    optional(string("-"))
    |> integer(min: 1)
    |> reduce({VM.Parser.Utils, :reduce_int, []})
    |> label("integer")
    # |> unwrap_and_tag(:integer)
  end

  def float_number do
    # -1.2213312e+308
    optional(string("-"))
    |> optional(integer(min: 1))
    |> string(".")
    |> integer(min: 1)
    |> optional(
      string("e")
      |> optional(choice([string("+"), string("-")]))
      |> integer(min: 1)
    )
    |> reduce({VM.Parser.Utils, :reduce_float, []})
    |> label("float")
  end


  @doc ~S"""
  A variable reference. Must start with a letter.
  Valid characters: uppercase, lowercase, numbers, underscore.
  These are going to be the IDs used internally, not user defined names (which will support UTF)
  Note that the return value is a charlist, not a string (no particular reason other than the ascii_char supports range).
  Currently no max length but should probably have one.
  """
  def parse_reference do
    ascii_char([?:])
    |> repeat(choice([
        ascii_char([?a..?z]),
        ascii_char([?A..?Z]),
        ascii_char([?0..?9]),
        ascii_char([?_])
      ]
    ))
    |> tag(:reference)
    |> label("reference")
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
    parse_reference: 0,
    unwrap: 1
  ]

  import VM.Parser.Boolean, only: [
    boolean_literal: 0,
    operator_not: 0
  ]

  # https://en.wikipedia.org/wiki/Operator-precedence_parser#section=2
  # Precedence climbing method (* repeat)
  # expression ::= equality-expression
  # equality-expression ::= additive-expression ( ( '==' | '!=' ) additive-expression ) *
  # additive-expression ::= multiplicative-expression ( ( '+' | '-' ) multiplicative-expression ) *
  # multiplicative-expression ::= primary ( ( '*' | '/' ) primary ) *

  defcombinatorp :additive_expression,
    ignore(whitespace())
    |> parsec(:multiplicative_expression)
    |> repeat(
      ignore(whitespace())
      |> unwrap_and_tag(choice([string("+"), string("-")]), :binopt)
      |> ignore(whitespace())
      |> parsec(:multiplicative_expression)
    )

  defcombinatorp :multiplicative_expression,
    ignore(whitespace())
    |> parsec(:primary_expression)
    |> repeat(
      ignore(whitespace())
      |> unwrap_and_tag(choice([string("*"), string("/")]), :binopt)
      |> ignore(whitespace())
      |> parsec(:primary_expression)
    )

  defcombinatorp :bool_or_expr,
    ignore(whitespace())
    |> parsec(:bool_and_expr)
    |> repeat(
      concat(ignore(whitespace()),
      VM.Parser.Boolean.operator_or())
      |> ignore(whitespace())
      |> parsec(:bool_and_expr)
    )


  defcombinatorp :bool_and_expr,
      ignore(whitespace())
      |> parsec(:bool_comparison_expr)
      |> repeat(
        concat(ignore(whitespace()),
        VM.Parser.Boolean.operator_and())
        |> ignore(whitespace())
        |> parsec(:bool_comparison_expr)
      )

  defcombinatorp :bool_comparison_expr,
    ignore(whitespace())
    |> parsec(:bool_primary_expr)
    |> repeat(
      concat(ignore(whitespace()),
        VM.Parser.Boolean.operator_is())   # TODO - Choice >=, <=, etc.
      |> ignore(whitespace())
      |> parsec(:bool_primary_expr)
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
      string("-") |> parsec(:primary_expression),
      parse_reference()             # Should be at the end usually.
    ])

  defcombinatorp :bool_primary_expr,
      choice([
        wrap(
          ignore(open_parens())
          |> ignore(whitespace())
          |> parsec(:expression)
          |> ignore(whitespace())
          |> ignore(close_parens())
        ),
        boolean_literal(),
        parse_reference()             # Should be at the end usually.
      ])

  # This whole thing could probably be implemented more efficiently with lookahead, but keeping it "simple" for now
  defcombinatorp :expression,
    repeat(choice([
      parsec(:additive_expression),
      parsec(:bool_or_expr)
    ]))

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
