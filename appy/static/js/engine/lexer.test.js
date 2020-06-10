import { lex } from "./lexer"
import { TOKEN_LITERAL, TOKEN_OPERATOR, TOKEN_START_BLOCK, TOKEN_CONTINUE_BLOCK, TOKEN_END_BLOCK, TOKEN_IDENTIFIER } from "./parser"

export function flatten_tokens(tokenQueue) {
    // Extract token into an array for testing ease
    let tokens = tokenQueue.asArray()
    let flat = [];
    tokens.forEach((token) => flat.push([
        token.value ? token.value : token.operator.keyword, 
        token.node_type
    ]))
    return flat;
}

test('lex floats', () => {
    expect(flatten_tokens(lex("3.1415"))).toEqual([[3.1415, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("9 .75 9"))).toEqual([[9, TOKEN_LITERAL], [.75, TOKEN_LITERAL], [9, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("9 1e10"))).toEqual([[9, TOKEN_LITERAL], [1e10, TOKEN_LITERAL]]);

    expect(flatten_tokens(lex("1e-10"))).toEqual([[1e-10, TOKEN_LITERAL]]);
    expect(flatten_tokens(lex("123e+12"))).toEqual([[123e+12, TOKEN_LITERAL]]);
    
    expect(flatten_tokens(lex("4.237e+101"))).toEqual([[4.237e+101, TOKEN_LITERAL]]);
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


test('lex multi-char operators', () => {
    // Interchangeable quotes
    expect(flatten_tokens(lex('1 ** 2 ** 3'))).toEqual([[1, TOKEN_LITERAL],['**', TOKEN_OPERATOR], [2, TOKEN_LITERAL], ['**', TOKEN_OPERATOR], [3, TOKEN_LITERAL] ]);
})


test('lex indentation levels', () => {
    // Interchangeable quotes
    expect(flatten_tokens(lex(`1\n2\n3`))).toEqual([
        [1, TOKEN_LITERAL],
        [TOKEN_CONTINUE_BLOCK, TOKEN_OPERATOR], 
        [2, TOKEN_LITERAL], 
        [TOKEN_CONTINUE_BLOCK, TOKEN_OPERATOR], 
        [3, TOKEN_LITERAL] 
    ]);


    expect(flatten_tokens(lex(`1\n\t2\n3`))).toEqual([
        [1, TOKEN_LITERAL],
        [TOKEN_START_BLOCK, TOKEN_OPERATOR], 
        [2, TOKEN_LITERAL], 
        [TOKEN_END_BLOCK, TOKEN_OPERATOR], 
        [3, TOKEN_LITERAL] 
    ]);

    // All active blocks closed at the end
    expect(flatten_tokens(lex(`
1
    2
        3`))).toEqual([
        [1, TOKEN_LITERAL],
        [TOKEN_START_BLOCK, TOKEN_OPERATOR], 
        [2, TOKEN_LITERAL], 
        [TOKEN_START_BLOCK, TOKEN_OPERATOR], 
        [3, TOKEN_LITERAL],
        [TOKEN_END_BLOCK, TOKEN_OPERATOR], 
        [TOKEN_END_BLOCK, TOKEN_OPERATOR], 
    ]);



    // Note: Tab here is meaningful for this test
    let result = flatten_tokens(lex(`
    1
        2
    3`));

    expect(result).toEqual([
            [1, TOKEN_LITERAL],
            [TOKEN_START_BLOCK, TOKEN_OPERATOR], 
            [2, TOKEN_LITERAL], 
            [TOKEN_END_BLOCK, TOKEN_OPERATOR], 
            [3, TOKEN_LITERAL],
        ]);    
})


test('lex attribute access', () => {
    let result = flatten_tokens(lex('User.name'));
    expect(result).toEqual([
        ["User", TOKEN_IDENTIFIER], 
        [".", TOKEN_OPERATOR],
        ["name", TOKEN_IDENTIFIER]
    ]);
})