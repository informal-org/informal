defmodule ParserTest do
  use ExUnit.Case
  doctest VM.Parser

  test "sub basic addition" do
    {:ok, parsed, _, _, _, _} = VM.Parser.parse("=1+1")
    assert parsed == [[integer: 1], {:binopt, "+"}, [integer: 1]]

    # TODO: Test for negative numbers.

  end

  test "recurses extra operations" do
    {:ok, parsed, "", _, _, _} = VM.Parser.parse("=1+2*3")
    assert parsed == [[integer: 1], {:binopt, "+"}, [[integer: 2], {:binopt, "*"}, [integer: 3]]]
    # TODO
  end


  # test "paren expressions" do
  #   {:ok, parsed, "", _, _, _} = VM.Parser.parse("=(1+2)*3")
  #   assert parsed == [[[integer: 1], {binopt: "+"}, [integer: 1]], {binopt: "*"}, [integer: 3]]
  #   # TODO
  # end

end
