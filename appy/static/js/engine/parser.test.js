import { lex } from "./lexer"
import { parse } from "./parser"


test('test add multiply precedence', () => {
    let tokens = lex("3 + 1 * 2 * 4 / 5")
    expect(parse(tokens).toString()).toEqual("(+ 3 (/ (* (* 1 2) 4) 5))")

    tokens = lex("1 * 2 + 3")
    // Multiply before addition
    expect(parse(tokens).toString()).toEqual("(+ (* 1 2) 3)")

    
    tokens = lex("1 + 2 * 3")
    // Multiply before addition
    expect(parse(tokens).toString()).toEqual("(+ 1 (* 2 3))")

    // Grouping. Addition before multiplication
    tokens = lex("(1 + 2) * 3")
    expect(parse(tokens).toString()).toEqual("(* (+ 1 2) 3)")

    // Test left-to-right order of the args
    tokens = lex("3 * (1 + 2)")
    expect(parse(tokens).toString()).toEqual("(* 3 (+ 1 2))")
});

test('test power operator', () => {
    let tokens = lex("2 ** 3 ** 4")
    let parsed = parse(tokens);
    // 3 ** 4 should evaluate first
    expect(parsed.toString()).toEqual("(** 2 (** 3 4))")

    // Unary minus should happen before the power

    tokens = lex("2 ** -3 ** 4")
    // 3 ** 4 should evaluate first
    expect(parse(tokens).toString()).toEqual("(** 2 (** (- 3) 4))")
})


test('test keyword definition', () => {
    // let tokens = flatten_tokens(lex("a: 2, b: 3, c: 5")
    // let tokens = lex("a: 2, b: 3, c: [5, 6, 7, 8]")
    let tokens = lex("a: 2, b: 3, c: 5")
    let ast = parse(tokens);
    expect(ast.toString()).toEqual("(: a,2 b,3 c,5)")

});