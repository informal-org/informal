import { lex } from "./lexer"
import { parseExpr } from "./parser"


test('test add multiply precedence', () => {
    expect(parseExpr("3 + 1 * 2 * 4 / 5").toString()).toEqual("(+ 3 (/ (* (* 1 2) 4) 5))")

    // Multiply before addition
    expect(parseExpr("1 * 2 + 3").toString()).toEqual("(+ (* 1 2) 3)")

    // Multiply before addition
    expect(parseExpr("1 + 2 * 3").toString()).toEqual("(+ 1 (* 2 3))")

    // Grouping. Addition before multiplication
    expect(parseExpr("(1 + 2) * 3").toString()).toEqual("(* (+ 1 2) 3)")

    // Test left-to-right order of the args
    expect(parseExpr("3 * (1 + 2)").toString()).toEqual("(* 3 (+ 1 2))")
});

test('test power operator', () => {
    // 3 ** 4 should evaluate first
    expect(parseExpr("2 ** 3 ** 4").toString()).toEqual("(** 2 (** 3 4))")

    // Unary minus should happen before the power
    expect(parseExpr("2 ** -3 ** 4").toString()).toEqual("(** 2 (** (- 3) 4))")
})


test('test map definition', () => {
    expect(parseExpr("a: 2, b: 3, c: 5").toString()).toEqual("(: a,2 b,3 c,5)")
});