import { lex } from "./lexer"
import { parse } from "./parser"



// test('test add multiply precedence', () => {
//     // Verify order of operands - multiply before addition
//     // 1 * 2 + 3 = 1 2 * 3 +
//     let tokens = flatten_tokens(lex("1 * 2 + 3"))
//     let postfix = applyOperatorPrecedence(tokens)
//     expect(postfix).toEqual([1, 2, "*", 3, "+"])

//     // Order reversed. 1 + 2 * 3 = 1 2 3 * +
//     tokens = flatten_tokens(lex("1 + 2 * 3"))
//     postfix = applyOperatorPrecedence(tokens)
//     expect(postfix).toEqual([1, 2, 3, "*", "+"])
// })

test('test add multiply grouping precedence', () => {
    // let tokens = lex("1 * (2 + 3)")

    // let tokens = lex("1 + 2 * 3")
    let tokens = lex("3 + 1 * 2 * 4 / 5")
//    console.log(tokens);
    let parsed = parse(tokens);
    console.log("Finished")
    console.log(parsed)
    if(parsed) {
        console.log(parsed.toString());
    }
    
    
    // let postfix = applyOperatorPrecedence(tokens)

    // Expect multiply before addition
    // expect(postfix).toEqual([1, 2, 3, "+", "*"])

    // tokens = flatten_tokens(lex("(1 + 2) * 3"))
    // postfix = applyOperatorPrecedence(tokens)
    // expect(postfix).toEqual([1, 2, "+", 3, "*"])
});


// test('test keyword definition', () => {
//     // let tokens = flatten_tokens(lex("a: 2, b: 3, c: 5")
//     let tokens = lex("a: 2, b: 3, c: [5, 6, 7, 8]")
//     console.log(tokens);
//     let ast = parse(tokens);
//     ast.toString()
//     // let postfix = applyOperatorPrecedence(tokens)
//     // console.log(postfix)


// });