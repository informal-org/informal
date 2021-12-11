import { StringType, Any, All, NoMatchError } from "@informal/compiler/parsec"

test('Matches to right node', () => {
    // Red, Green, Blue
    let colors = new Any()
    let red = new StringType("Red")
    let green = new StringType("Green")
    let blue = new StringType("Blue")
    colors.add(red);
    colors.add(green);
    colors.add(blue);
    expect(colors.match("Red").match.matcher).toEqual(red)
    expect(colors.match("Green").match.match).toEqual("Green")
    expect(() => colors.match("yellow")).toThrow(NoMatchError)
    
});

test('Prioritizes choices by nesting order', () => {
    // All choices within a given level are treated equally.
    // (add, sub), (multiply, divide) - addition or subtraction have equal precedence.
    // Their precedence is lower than the multiply or divide precedence.
    // Within a choice, all options have the same priority. 
    // If you group two elements its to be treated as if they're one group priority.
    let add_sub = new Any();
    let add = new StringType("+")
    let sub = new StringType("-")
    add_sub.add(add)
    add_sub.add(sub)

    let mul_div = new Any()
    let mul = new StringType("*")
    let div = new StringType("/")
    mul_div.add(mul)
    mul_div.add(div)

    let ops = new Any();
    ops.add(mul_div)
    ops.add(add_sub)
    
    // expect(ops.match("+*")).toEqual([red, ""])
})

test('Prefix match', () => {

})

test('Variable extraction', () => {
    // T-10 - Prefix match on T-. Extract 10 as a number.
})

test('Match on variable type options', () => {
    // T-10 vs T-STR - string vs numeric match.
    // With options for length, range, etc. per type.
    // Number, boolean, string.
})

test('Backtracking recursive parsers', () => {
    // Mathematical expressions. +/-, etc.
})

test('Associtivity', () => {

})