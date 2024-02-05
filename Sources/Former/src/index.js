import { lex } from "./lexer.js";
import {parseExpr} from "./parser.js";
import {interpret, builtins} from "./interpreter.js";


// const tokens = lex("1 + 2 * 3 - 4 / 5");
// console.log(tokens.asArray());
// const tokens = lex("add(a, b): _primitive_add(a, b)");
// const tokens = lex("__builtin_add(1, 2)");

// console.log(tokens.asArray());

// const token_vals = tokens.asArray().map((token) => { return token ? token.value : token; });
// console.log(token_vals);

// const parsed = parseExpr("1 + 2 * 5 - 4 / 5");
// const parsed = parseExpr("foo(a, b): __builtin_add(a, b)");
// Parser doesn't support types yet. Int foo, Int a, etc.
const parsed = parseExpr("foo(a,b): __builtin_add(a,b)");
console.log(parsed);

const fn_def = interpret(parsed, builtins);
console.log(interpret(parseExpr("foo(3,5)"), fn_def.env));