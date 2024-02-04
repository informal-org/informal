import { lex } from "./lexer.js";


const tokens = lex("1 + 2 * 3 - 4 / 5");

const token_vals = tokens.asArray().map((token) => { return token ? token.value : token; });
console.log(token_vals);

