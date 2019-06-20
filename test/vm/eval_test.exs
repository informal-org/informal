defmodule EvalTest do
  use ExUnit.Case
  doctest VM

  test "eval arithmetic" do
    # assert VM.eval_expr("= 1 + 1") == 2
    # assert VM.eval_expr("= 23 + 19") == 42
    # assert VM.eval_expr("= 3 + 4 * 5") == 23
    # assert VM.eval_expr("= (3 + 4) * 5") == 35
    # assert VM.eval_expr("= (3 + 4) * -10") == -70
    # assert VM.eval_expr("= (3.5 + 4) * -10") == -75.0
    # assert VM.eval_expr("= (-.5 + 4) * 10") == 35.0
    expr = %{
      "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
      "operator" => "+",
      "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
      "type" => "BinaryExpression"
    }
    assert VM.eval_expr(expr, %{}) == 2
  end


  test "unary negative" do
    # 1 + 5 * -3
    expr = %{
      "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
      "operator" => "+",
      "right" => %{
        "left" => %{"raw" => "5", "type" => "Literal", "value" => 5},
        "operator" => "*",
        "right" => %{
          "argument" => %{"raw" => "3", "type" => "Literal", "value" => 3},
          "operator" => "-",
          "prefix" => true,
          "type" => "UnaryExpression"
        },
        "type" => "BinaryExpression"
      },
      "type" => "BinaryExpression"
    }

    assert VM.eval_expr(expr, %{}) == -14

  end

  test "bool equality check" do
    # 1 + 1 is 2
    expr = %{
      "left" => %{
        "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
        "operator" => "+",
        "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
        "type" => "BinaryExpression"
      },
      "operator" => "is",
      "right" => %{"raw" => "2", "type" => "Literal", "value" => 2},
      "type" => "BinaryExpression"
    }

    assert VM.eval_expr(expr, %{}) == true
  end


  test "Simple multi cell evaluation" do
    body = %{
      "id01" => %{
        "depends_on" => [],
        "id" => "id01",
        "input" => "1 + 1",
        "parsed" => %{
          "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "operator" => "+",
          "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "type" => "BinaryExpression"
        }
      },
      "id02" => %{
        "depends_on" => [],
        "id" => "id02",
        "input" => "2 + 3",
        "parsed" => %{
          "left" => %{"raw" => "2", "type" => "Literal", "value" => 2},
          "operator" => "+",
          "right" => %{"raw" => "3", "type" => "Literal", "value" => 3},
          "type" => "BinaryExpression"
        }
      }
    }
    VM.eval(body)

  end

  test "Simple dependency evaluation" do
    body = %{
      "id01" => %{
        "depends_on" => [],
        "id" => "id01",
        "input" => "1 + 1",
        "parsed" => %{
          "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "operator" => "+",
          "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "type" => "BinaryExpression"
        }
      },
      "id02" => %{
        "depends_on" => ["id01"],
        "id" => "id02",
        "input" => "2 + id01",
        "parsed" => %{
          "left" => %{"raw" => "2", "type" => "Literal", "value" => 2},
          "operator" => "+",
          "right" => %{"name" => "id01", "type" => "Identifier"},
          "type" => "BinaryExpression"
        }
      }
    }

    VM.eval(body)
  end

  test "Circular dependency filtering" do
    body = %{
      "id01" => %{
        "depends_on" => ["id02"],
        "id" => "id01",
        "input" => "id02 + 1",
        "parsed" => %{
          "left" => %{"name" => "id02", "type" => "Identifier"},
          "operator" => "+",
          "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "type" => "BinaryExpression"
        }
      },
      "id02" => %{
        "depends_on" => ["id01"],
        "id" => "id02",
        "input" => "2 + id01",
        "parsed" => %{
          "left" => %{"raw" => "2", "type" => "Literal", "value" => 2},
          "operator" => "+",
          "right" => %{"name" => "id01", "type" => "Identifier"},
          "type" => "BinaryExpression"
        }
      },
      "id03" => %{
        "depends_on" => [],
        "id" => "id03",
        "input" => "1 + 1",
        "parsed" => %{
          "left" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "operator" => "+",
          "right" => %{"raw" => "1", "type" => "Literal", "value" => 1},
          "type" => "BinaryExpression"
        }
      },
      "id04" => %{
        "depends_on" => ["id03"],
        "id" => "id04",
        "input" => "id03 + 3",
        "parsed" => %{
          "left" => %{"name" => "id03", "type" => "Identifier"},
          "operator" => "+",
          "right" => %{"raw" => "3", "type" => "Literal", "value" => 3},
          "type" => "BinaryExpression"
        }
      }
    }

    VM.eval(body)
  end

  test "Cyclic node filtering" do
    cycles = ["id02", "id01"]
    dep_map = [{"id01", ["id02"]}, {"id02", ["id01"]}, {"id03", []}, {"id04", ["id03"]}]
    assert VM.filter_cycles(dep_map, cycles) == [{"id03", []}, {"id04", ["id03"]}]
  end


end
