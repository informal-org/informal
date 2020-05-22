import jsep from "jsep";

jsep.addBinaryOp("or", 1);
jsep.addBinaryOp("and", 2);

jsep.addUnaryOp("not");

// Remove un-supported operations - use verbal names for these instead. 
jsep.removeBinaryOp("||");
jsep.removeBinaryOp("&&");
jsep.removeBinaryOp("|");
jsep.removeBinaryOp("&");
// jsep.removeBinaryOp("==");
// jsep.removeBinaryOp("!=");  // not (a = b). Excel does <>
jsep.removeBinaryOp("===");
jsep.removeBinaryOp("!==");
jsep.removeBinaryOp("<<");
jsep.removeBinaryOp(">>");
jsep.removeBinaryOp(">>>");


jsep.removeUnaryOp("!")
jsep.removeUnaryOp("~")


// var reserved_words = ["AND", "OR", "NOT", "TRUE", "FALSE"];
// const BUILTIN_SYMBOLS = {
//     "AND": function() {},
//     "OR": function() {}, 
//     "NOT": function() {},
//     "TRUE": true,
//     "FALSE": false,
// }

// export function lowercaseKeywords(formula) {
//     // Convert reserved keywords like "and" to uppercase AND so they can be matched by jsep regardless of case.
//     // This could potentially be done in a single regex rather than multiple passes over string
//     // but this is good enough for normal sized expressions.
//     reserved_words.forEach((keyword) => {
//         let keyexp = "(\\W|\^)" + keyword + "(\\W|\$)";
//         formula = formula.replace(new RegExp(keyexp, 'gi'), "$1" + keyword.toLowerCase() + "$2");
//     })
//     return formula;
// }


export function parse(expr) {
    let parsed = jsep(expr)
    console.log(parsed);
    return parsed;
}

function parseAll(cells) {
    for(var id in cells){
        let cell = cells[id];
        // cell.parsed = parse(cell.expr);
    }
    return cells
}

