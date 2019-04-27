defmodule ParserTest do
  use ExUnit.Case
  doctest VM.Parser

  test "sub basic addition" do
    {:ok, parsed, _, _, _, _} = VM.Parser.parse("= 1 + 1")
    assert parsed == [integer: 1, binopt: "+", integer: 1]

    # TODO: Test for negative numbers.

  end

  test "conversion to prefix tree" do
    assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2"]) == {"+", ["1", "2"]}
    assert VM.Parser.Helpers.to_prefix_tree(["1", "+", "2", "+", "3"]) == {"+", [{"+", ["1", "2"]}, "3"]}

    # TO operator precedence with pemdas
  end

  test "recurses extra operations" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("= 1 + 1 + 2")
    assert parsed != [integer: 1, binopt: "+", integer: 1]
    # TODO
  end

end
