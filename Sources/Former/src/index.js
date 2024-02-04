import { lex } from "./lexer.js";
import {parseExpr} from "./parser.js";


const tokens = lex("1 + 2 * 3 - 4 / 5");
console.log(tokens.asArray());
// const tokens = lex("add(a, b): _primitive_add(a, b)");
// const tokens = lex("__builtin_add(1, 2)");

// console.log(tokens.asArray());

const token_vals = tokens.asArray().map((token) => { return token ? token.value : token; });
console.log(token_vals);

const parsed = parseExpr("1 + 2 * 5 - 4 / 5");
console.log(parsed);