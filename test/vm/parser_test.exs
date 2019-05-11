defmodule ParserTest.ArithmeticTest do
  use ExUnit.Case

  test "sub basic addition" do
    # {:ok, parsed, "", _, _, _} = VM.Parser.parse("= 140 + 2")
    # assert parsed == [[[integer: 140], {:binopt, "+"}, [integer: 2]]]
  end
end


defmodule ParserTest.BooleanTest do
  use ExUnit.Case

  test "basic boolean parse" do
    # {:ok, parsed, "", _, _, _} = VM.Parser.parse("= true or false")
    # assert parsed == [[[[true]], :op_or, [[false]]]]
  end
end
