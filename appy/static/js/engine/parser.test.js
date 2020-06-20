import { lex } from "./lexer"
import { parseExpr } from "./parser"


test('test add multiply precedence', () => {
    expect(parseExpr("3 + 1 * 2 * 4 / 5").toString()).toEqual("(+ 3 (/ (* (* 1 2) 4) 5))")

    // Multiply before addition
    expect(parseExpr("1 * 2 + 3").toString()).toEqual("(+ (* 1 2) 3)")

    // Multiply before addition
    expect(parseExpr("1 + 2 * 3").toString()).toEqual("(+ 1 (* 2 3))")

    // Grouping. Addition before multiplication
    expect(parseExpr("(1 + 2) * 3").toString()).toEqual("(* ((grouping) (+ 1 2)) 3)")

    expect(parseExpr("(2 + 3) * 4").toString()).toEqual("(* ((grouping) (+ 2 3)) 4)")

    // Test left-to-right order of the args
    expect(parseExpr("3 * (1 + 2)").toString()).toEqual("(* 3 ((grouping) (+ 1 2)))")
});

test('test power operator', () => {
    // 3 ** 4 should evaluate first
    expect(parseExpr("2 ** 3 ** 4").toString()).toEqual("(** 2 (** 3 4))")

    // Unary minus should happen before the power
    expect(parseExpr("2 ** -3 ** 4").toString()).toEqual("(** 2 (** (- 3) 4))")
})


test('test map definition', () => {
    expect(parseExpr("a: 2, b: 3, c: 5").toString()).toEqual("(: a,2 b,3 c,5)")

    expect(parseExpr("a: 2 + (3 * 5), b: 8").toString()).toEqual("(: a,(+ 2 ((grouping) (* 3 5))) b,8)")
});


test('test function application', () => {
    let parsed = parseExpr("f(1)");
    expect(parsed.node_type).toEqual("apply")
    expect(parsed.left.toString()).toEqual("f")
    expect(parsed.value.toString()).toEqual("1")
});

test('test filtering', () => {
    expect(parseExpr("Users[id == 3 or points > 10]").toString()).toEqual("([ Users (or (== id 3) (> points 10)))")
});


test('test multi-param methods', () => {
    // Extra paren at beginning indicates grouping
    expect(parseExpr("(a, b): a + b").toString()).toEqual("(: ((grouping) a b) (+ a b))")
});


test('test equality', () => {
    expect(parseExpr("x > 7 == false").toString()).toEqual("(== (> x 7) (false))")

});


test('test function signature', () => {
    expect(parseExpr("(a, b) [a > 0]: a + b").toString()).toEqual("(: ([ ((grouping) a b) (> a 0)) (+ a b))")

});
