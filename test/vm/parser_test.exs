defmodule ParserTest do
  use ExUnit.Case
  doctest VM.Parser

  test "sub basic addition" do
    {:ok, parsed, _, _, _, _} = VM.Parser.parse("= 140 + 2")
    assert parsed == [[[integer: 140], {:binopt, "+"}, [integer: 2]]]

    assert VM.recurse_expr(parsed) == 142

    # TODO: Test for negative numbers.
  end

    test "conversion to prefix tree" do
      assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2"]) == ["+", ["1", "2"]]
      assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2", "+", "3"]) == ["+", [["+", ["1", "2"]], "3"]]

      # TO operator precedence with pemdas
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

end
