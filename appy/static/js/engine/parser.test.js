import { lex, applyOperatorPrecedence, TOKEN_LITERAL, TOKEN_OPERATOR } from "./parser"

test('lex floats', () => {
    expect(lex("3.1415")).toEqual([[3.1415, TOKEN_LITERAL]]);
    expect(lex("9 .75 9")).toEqual([[9, TOKEN_LITERAL], [.75, TOKEN_LITERAL], [9, TOKEN_LITERAL]]);
    expect(lex("9 1e10")).toEqual([[9, TOKEN_LITERAL], [1e10, TOKEN_LITERAL]]);

    expect(lex("1e-10")).toEqual([[1e-10, TOKEN_LITERAL]]);
    expect(lex("123e+12")).toEqual([[123e+12, TOKEN_LITERAL]]);
    
    expect(lex("4.237e+101")).toEqual([[4.237e+101, TOKEN_LITERAL]]);

    // Errors on undefined exponents
    expect(() => lex("4.1e")).toThrow();
    expect(() => lex("5.1e ")).toThrow();
})

test('lex unary minus', () => {
    expect(lex("-1")).toEqual([[-1, TOKEN_LITERAL]]);
    expect(lex("-.05")).toEqual([[-.05, TOKEN_LITERAL]]);
    expect(lex("5-2")).toEqual([[5, TOKEN_LITERAL], ["-", TOKEN_OPERATOR], [2, TOKEN_LITERAL]]);
    expect(lex("5 -.2")).toEqual([[5, TOKEN_LITERAL], ["-", TOKEN_OPERATOR], [.2, TOKEN_LITERAL]]);

    expect(lex("5 + -.2")).toEqual([[5, TOKEN_LITERAL],["+", TOKEN_OPERATOR], [-0.2, TOKEN_LITERAL]]);
    expect(lex("5 * -2")).toEqual([[5, TOKEN_LITERAL], ["*", TOKEN_OPERATOR], [-2, TOKEN_LITERAL]]);

    // We don't support unary minus for identifiers or groups -(1 + 1) right now
})

test('lex string', () => {
    // Interchangeable quotes
    expect(lex('"hello world"')).toEqual([["hello world", TOKEN_LITERAL]]);
    expect(lex("'hello world' 42")).toEqual([["hello world", TOKEN_LITERAL], [42, TOKEN_LITERAL]]);
    
    // Escaping
    expect(lex("'hello' + \"world\"")).toEqual([["hello", TOKEN_LITERAL], ["+", TOKEN_OPERATOR], ["world", TOKEN_LITERAL]]);

    // Unterminated string
    expect(() => lex('"hello')).toThrow();
})

test('test add multiply precedence', () => {
    // Verify order of operands - multiply before addition
    // 1 * 2 + 3 = 1 2 * 3 +
    let tokens = lex("1 * 2 + 3")
    let postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, "*", 3, "+"])

    // Order reversed. 1 + 2 * 3 = 1 2 3 * +
    tokens = lex("1 + 2 * 3")
    postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, 3, "*", "+"])
})

test('test add multiply grouping precedence', () => {
    let tokens = lex("1 * (2 + 3)")
    let postfix = applyOperatorPrecedence(tokens)

    // Expect multiply before addition
    expect(postfix).toEqual([1, 2, 3, "+", "*"])

    tokens = lex("(1 + 2) * 3")
    postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, "+", 3, "*"])
});