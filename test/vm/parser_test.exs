defmodule ParserTest do
  use ExUnit.Case
  doctest VM.Parser.Utils
  doctest VM.Parser

  test "conversion to prefix tree" do
    assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2"]) == ["+", ["1", "2"]]
    assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2", "+", "3"]) == ["+", [["+", ["1", "2"]], "3"]]

    # TO operator precedence with pemdas
  end

  test "whitespace placement" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= 9")
    assert parsed == [[[integer: 9]]]
  end

  test "variable reference parse" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= -.5 + :Var32")
    assert parsed == [[[float: -0.5], {:binopt, "+"}, [reference: ':Var32']]]
  end


end

defmodule ParserTest.ArithmeticTest do
  use ExUnit.Case

  test "sub basic addition" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= 140 + 2")
    assert parsed == [[[integer: 140], {:binopt, "+"}, [integer: 2]]]

    assert VM.recurse_expr(parsed) == 142

    # TODO: Test for negative numbers.
  end

  test "negative number addition" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= 140 + -2")
    assert parsed == [[[integer: 140], {:binopt, "+"}, [integer: -2]]]

    # assert VM.recurse_expr(parsed) == 138

    # TODO: Test for negative numbers.
  end


  test "recurses extra operations" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("=1+2*3")
    assert parsed == [[[integer: 1], {:binopt, "+"}, [integer: 2, binopt: "*", integer: 3]]]
  end

  test "paren expressions" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("=(1+2)*3")
    # This is horrible. Why is it so nested!? !!!
    assert parsed == [[[[[[integer: 1], {:binopt, "+"}, [integer: 2]]], {:binopt, "*"}, {:integer, 3}]]]
  end

  test "float parse" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= .5 + 1.328")
    assert parsed == [[[{:float, 0.5}], {:binopt, "+"}, [float: 1.328]]]
    assert parsed == [[[float: 0.5], {:binopt, "+"}, [float: 1.328]]]
  end

  test "float negative parse" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= -.5 + -1.328")
    assert parsed == [[[float: -0.5], {:binopt, "+"}, [float: -1.328]]]
  end

end


defmodule ParserTest.BooleanTest do
  use ExUnit.Case

  test "basic boolean parse" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= true or false")
    assert parsed == [[[[true]], :op_or, [[false]]]]
  end

  test "and or precedence" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= true or false and true")
    # And has precedence over or
    assert parsed == [[[[true]], :op_or, [[false], :op_and, [true]]]]
  end

  test "bool parens precedence" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= (true or false) and true")
    # And has precedence over or
    assert parsed == [[[[[true]], :op_or, [false]], :op_and, [true]]]
  end


end
