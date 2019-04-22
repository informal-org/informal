defmodule ParserTest do
  use ExUnit.Case
  doctest VM.Parser

  test "sub basic addition" do
    {:ok, parsed, _, _, _, _} = VM.Parser.expression("= 1 + 1")
    assert parsed == [integer: 1, operator: "+", integer: 1]
  end

  test "recurses extra operations" do
    {:ok, parsed, _, _, _, _} = VM.Parser.expression("= 1 + 1 + 2")
    assert parsed != [integer: 1, operator: "+", integer: 1]
    # TODO
  end

end
