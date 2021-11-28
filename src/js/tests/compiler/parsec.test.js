import { StringType, Any, All } from "@informal/compiler/parsec"

test('Matches to right node', () => {
    // Red, Green, Blue
    console.log("Any is")
    let colors = new Any()
    let red = new StringType("Red")
    let green = new StringType("Green")
    let blue = new StringType("Blue")
    colors.add(red);
    colors.add(green);
    colors.add(blue);
    expect(colors.match("Red")).toEqual([red, ""])
    
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