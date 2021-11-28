import { ParsecMatcher } from "@informal/compiler/parsec"

test('Matches to right node', () => {
    // Red, Green, Blue
    let colors = new ParsecObj()
    let red = colors.addAttr(new ParsecObj("", "Red"))
    let green = colors.addAttr(new ParsecObj("", "Green"))
    let blue = colors.addAttr(new ParsecObj("", "Blue"))
    expect(add(1, 2).toString()).toEqual("true")
});

test('Chooses between options', () => {

})

test('Prioritizes choices by nesting order', () => {
    // All choices within a given level are treated equally.
    // (add, sub), (multiply, divide) - addition or subtraction have equal precedence.
    // Their precedence is lower than the multiply or divide precedence.
    // Within a choice, all options have the same priority. 
    // If you group two elements its to be treated as if they're one group priority.

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