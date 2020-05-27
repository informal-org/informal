import { lex } from "./parser"

test('lex floats', () => {
    expect(lex("3.1415")).toEqual([3.1415]);
    expect(lex("9 .75 9")).toEqual([9, .75, 9]);
    expect(lex("9 1e10")).toEqual([9, 1e10]);

    expect(lex("1e-10")).toEqual([1e-10]);
    expect(lex("123e+12")).toEqual([123e+12]);
    
    expect(lex("4.237e+101")).toEqual([4.237e+101]);

    // Errors on undefined exponents
    expect(() => lex("4.1e")).toThrow();
    expect(() => lex("5.1e ")).toThrow();
})

test('lex unary minus', () => {
    expect(lex("-1")).toEqual([-1]);
    expect(lex("-.05")).toEqual([-.05]);
    expect(lex("5-2")).toEqual([5, "-", 2]);
    expect(lex("5 -.2")).toEqual([5, "-", .2]);

    expect(lex("5 + -.2")).toEqual([5, "+", -0.2]);
    expect(lex("5 * -2")).toEqual([5, "*", -2]);

    // We don't support unary minus for identifiers or groups -(1 + 1) right now
})

test('lex string', () => {
    // Interchangeable quotes
    expect(lex('"hello world"')).toEqual(["hello world"]);
    expect(lex("'hello world' 42")).toEqual(["hello world", 42]);
    
    // Escaping
    expect(lex("'hello' + \"world\"")).toEqual(["hello", "+", "world"]);

    // Unterminated string
    expect(() => lex('"hello')).toThrow();

})

