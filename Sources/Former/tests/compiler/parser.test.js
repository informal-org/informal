// import { lex } from "@informal/compiler/lexer.js"
import { parseExpr } from "@informal/compiler/parser.js"


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
    let result = parseExpr("a: 2, b: 3, c: 5");
    // expect(result.toString()).toEqual("(: a,2 b,3 c,5)")
    expect(result.toString()).toEqual("({ (: a 2) (: b 3) (: c 5))")
    // expect(parseExpr("a: 2 + (3 * 5), b: 8").toString()).toEqual("(: a,(+ 2 ((grouping) (* 3 5))) b,8)")
    expect(parseExpr("a: 2 + (3 * 5), b: 8").toString()).toEqual("({ (: a (+ 2 ((grouping) (* 3 5)))) (: b 8))")
});


test('test function application', () => {
    let parsed = parseExpr("f(1)");
    expect(parsed.node_type).toEqual("apply")
    expect(parsed.left.toString()).toEqual("f")
    expect(parsed.value.toString()).toEqual("1")
});

test('test multi param application', () => {
    let parsed = parseExpr("f(1, 2)");
    expect(parsed.node_type).toEqual("apply")
    expect(parsed.left.toString()).toEqual("f")
    expect(parsed.value.toString()).toEqual("1,2")
});

test('test filtering', () => {
    let result = parseExpr("Users[id == 3 or points > 10]")
    expect(result.toString()).toEqual("([ Users (or (== id 3) (> points 10)))")
});


test('test multi-param methods', () => {
    // Extra paren at beginning indicates grouping
    expect(parseExpr("(a, b): a + b").toString()).toEqual("(: ((grouping) a b) (+ a b))")
});


test('test equality', () => {
    expect(parseExpr("x > 7 == false").toString()).toEqual("(== (> x 7) false)")

});

// Old way of doing function guards...
test('test function signature', () => {
    expect(parseExpr("(a, b) [a > 0]: a + b").toString()).toEqual("(: ([ ((grouping) a b) (> a 0)) (+ a b))")
});

// test('test native function calls', () => {
//     let result = parseExpr('"hello".uppercase()')
//     expect(result.toString()).toEqual("(: ([ ((grouping) a b) (> a 0)) (+ a b))")
// });


test('test guard statements', () => {
    expect(parseExpr("(a, b) if(a > 0): a + b").toString()).toEqual("(: (if ((grouping) a b) ((grouping) (> a 0))) (+ a b))")
});

test('test conditional statements', () => {
    expect(parseExpr("if(a > 0): a + b").toString()).toEqual("(: (if ((grouping) (> a 0))) (+ a b))")
    expect(parseExpr("if a > 0: a + b").toString()).toEqual("(: (if (> a 0)) (+ a b))")
});

test('test indentation blocks', () => {
    let result = parseExpr("(x, y) if(x <= y): x\n(x, y): y");
    expect(result.toString()).toEqual("({ (: (if ((grouping) x y) ((grouping) (<= x y))) x) (: ((grouping) x y) y))")
})

test('test multiline blocks', () => {
    let expr = "0: 1\n2: 10\n3: 15"
    let result = parseExpr(expr)
    expect(result.toString()).toEqual("({ (: 0 1) (: 2 10) (: 3 15))")
})

test('test multiblock conditional', () => {
    let expr = `0: 1
(x, y):
    if x < y or x > 23: x
    if x > y: y
    if x == y: "Equal"`
    let result = parseExpr(expr);
    console.log(result);
    expect(result.toString()).toEqual("({ (: 0 1) (: ((grouping) x y) ((startblock) (: (if (or (< x y) (> x 23))) x) (: (if (> x y)) y) (: (if (== x y)) Equal))))")
})

test('test range', () => {
    let expr, result;
    // TODO;
    // expr = '[1, 2, 3, .., 10, 20]';
    // result  = parseExpr(expr);
    // expect(result.toString()).toEqual("([ 1 2 3 (.. (,) 10) 20)")

    expr = '[10, 20, ..100]';
    result  = parseExpr(expr);
    expect(result.toString()).toEqual("([ 10 20 (.. 100))")

    expr = '[5..]';
    result  = parseExpr(expr);
    expect(result.toString()).toEqual("([ (.. 5))")    
});

test('test assignment', () => {
    let expr = "a = b + c"
    let result = parseExpr(expr)
    expect(result.toString()).toEqual("(= a (+ b c))")
})