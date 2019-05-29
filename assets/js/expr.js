import * as jsep from "jsep"

// Override default jsep expressions with our language equivalents.
// Semi case-insensitive. Done at the parser level so we get clean input.
jsep.addBinaryOp("OR", 1);
jsep.addBinaryOp("Or", 1);
jsep.addBinaryOp("or", 1);

jsep.addBinaryOp("AND", 2);
jsep.addBinaryOp("And", 2);
jsep.addBinaryOp("and", 2);

jsep.addBinaryOp("MOD", 10);
jsep.addBinaryOp("Mod", 10);
jsep.addBinaryOp("mod", 10);

jsep.addBinaryOp("IS", 6);  // 6 is Priority of ==
jsep.addBinaryOp("Is", 6);
jsep.addBinaryOp("is", 6);

jsep.addUnaryOp("NOT");
jsep.addUnaryOp("Not");
jsep.addUnaryOp("not");

// Remove un-supported operations - use verbal names for these instead. 
jsep.removeBinaryOp("%");
jsep.removeBinaryOp("||");
jsep.removeBinaryOp("&&");
jsep.removeBinaryOp("|");
jsep.removeBinaryOp("&");
jsep.removeBinaryOp("==");
jsep.removeBinaryOp("!=");  // not (a = b). Excel does <>
jsep.removeBinaryOp("===");
jsep.removeBinaryOp("!==");
jsep.removeBinaryOp("<<");
jsep.removeBinaryOp(">>");
jsep.removeBinaryOp(">>>");

jsep.removeUnaryOp("!")
jsep.removeUnaryOp("~")

jsep.addLiteral("True", true)
jsep.addLiteral("TRUE", true)

jsep.addLiteral("False", false)
jsep.addLiteral("FALSE", false)

export default function parseExpr(expr) {
    let parsed = jsep(expr)
    console.log(parsed);
    return parsed;
}