import { lex, applyOperatorPrecedence, TOKEN_LITERAL, TOKEN_OPERATOR } from "./parser"

function flatten_tokens(tokenQueue) {
    // Extract token into an array for testing ease
    let tokens = tokenQueue.asArray()
    let flat = [];
    tokens.forEach((token) => flat.push([token.value, token.token_type]))
    return flat;
}

test('lex floats', () => {
    expect(flatten_tokens(lex("3.1415"))).toEqual([[3.1415, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("9 .75 9"))).toEqual([[9, TOKEN_LITERAL], [.75, TOKEN_LITERAL], [9, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("9 1e10"))).toEqual([[9, TOKEN_LITERAL], [1e10, TOKEN_LITERAL]]);

    expect(flatten_tokens(lex("1e-10"))).toEqual([[1e-10, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("123e+12"))).toEqual([[123e+12, TOKEN_LITERAL]]);
    
    expect(flatten_tokens(lex("4.237e+101"))).toEqual([[4.237e+101, TOKEN_LITERAL]]);

    // Errors on undefined exponents
    expect(() => lex("4.1e")).toThrow();
    expect(() => lex("5.1e ")).toThrow();
})

test('lex unary minus', () => {
    expect(flatten_tokens(lex("-1"))).toEqual([[-1, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("-.05"))).toEqual([[-.05, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("5-2"))).toEqual([[5, TOKEN_LITERAL], ["-", TOKEN_OPERATOR], [2, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("5 -.2"))).toEqual([[5, TOKEN_LITERAL], ["-", TOKEN_OPERATOR], [.2, TOKEN_LITERAL]]);

    expect(flatten_tokens(lex("5 + -.2"))).toEqual([[5, TOKEN_LITERAL],["+", TOKEN_OPERATOR], [-0.2, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("5 * -2"))).toEqual([[5, TOKEN_LITERAL], ["*", TOKEN_OPERATOR], [-2, TOKEN_LITERAL]]);

    // We don't support unary minus for identifiers or groups -(1 + 1) right now
})

test('lex string', () => {
    // Interchangeable quotes
    expect(flatten_tokens(lex('"hello world"'))).toEqual([["hello world", TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("'hello world' 42"))).toEqual([["hello world", TOKEN_LITERAL], [42, TOKEN_LITERAL]]);
    
    // Escaping
    expect(flatten_tokens(lex("'hello' + \"world\""))).toEqual([["hello", TOKEN_LITERAL], ["+", TOKEN_OPERATOR], ["world", TOKEN_LITERAL]]);

    // Unterminated string
    expect(() => lex('"hello')).toThrow();
})

test('test add multiply precedence', () => {
    // Verify order of operands - multiply before addition
    // 1 * 2 + 3 = 1 2 * 3 +
    let tokens = flatten_tokens(lex("1 * 2 + 3"))
    let postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, "*", 3, "+"])

    // Order reversed. 1 + 2 * 3 = 1 2 3 * +
    tokens = flatten_tokens(lex("1 + 2 * 3"))
    postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, 3, "*", "+"])
})

test('test add multiply grouping precedence', () => {
    let tokens = flatten_tokens(lex("1 * (2 + 3)"))
    let postfix = applyOperatorPrecedence(tokens)

    // Expect multiply before addition
    expect(postfix).toEqual([1, 2, 3, "+", "*"])

    tokens = flatten_tokens(lex("(1 + 2) * 3"))
    postfix = applyOperatorPrecedence(tokens)
    expect(postfix).toEqual([1, 2, "+", 3, "*"])
});


test('test keyword definition', () => {
    // let tokens = flatten_tokens(lex("a: 2, b: 3, c: 5")
    let tokens = flatten_tokens(lex("a: 2, b: 3, c: [5, 6, 7, 8]"))
    let postfix = applyOperatorPrecedence(tokens)
    console.log(postfix)


});