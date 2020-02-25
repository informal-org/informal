import jsep from "jsep";


// jsep.addBinaryOp("=", 6);
// TODO: Make these case insensitive as well

jsep.addBinaryOp("or", 1);
jsep.addBinaryOp("and", 2);
jsep.addBinaryOp("mod", 10);


// jsep.addBinaryOp("where", 0); // Should be evaluated after "=" and other conditionals. So < 6.

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

var reserved_words = ["AND", "OR", "NOT", "MOD", "TRUE", "FALSE"];  // TODO: TRUE, FALSE

export function lowercaseKeywords(formula) {
    // Convert reserved keywords like "and" to uppercase AND so they can be matched by jsep regardless of case.
    // This could potentially be done in a single regex rather than multiple passes over string
    // but this is good enough for normal sized expressions.
    reserved_words.forEach((keyword) => {
        let keyexp = "(\\W|\^)" + keyword + "(\\W|\$)";
        formula = formula.replace(new RegExp(keyexp, 'gi'), "$1" + keyword.toLowerCase() + "$2");
    })
    return formula;
}


export function parseFormula(expr){
    // Assert is formula
    // Return jsep expression
    let formula = expr; //.substring(1);
    if(util.isDefinedStr(formula)){
        formula = lowercaseKeywords(formula);
        let parsed = jsep(formula);
        return parsed;
    }
    return null;
}


function parse(expr) {
    let parsed = jsep(expr);
    console.log(parsed);
    return parsed;
}

function computeDeps() {

}

function generateCode(expr) {
    // {id, name, input}
    // TODO: Generate safe names
    // var variable_name = cell.name;

    // return `var ${variable_name} = ${cell.input}; ${cell.input}`;

    function ctx_init() {
        var ctx = {};
        return {
            set: function(k, v) { ctx[k] = v; },
            get: function(k) { return ctx[k]; },
            all: function() { return ctx }
        };
    };

    var code = "" + ctx_init.toString() + "\n; var ctx = ctx_init();";
    expr.body.forEach((cell) => {
        var variable_name = cell.name;
        parse(cell.input);
        code += `var ${variable_name} = ${cell.input};\n`;
        code += `ctx.set(${cell.id}, ${variable_name});\n`;
    })

    code += "ctx.all();\n"

    console.log(code);
    return code;
}

function execCode(code) {
    // TODO: Sandboxed execution
    return eval(code);
}

export function evaluate(expr) {
    console.log("Evaluating");
    console.log(expr);
    
    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    let code = generateCode(expr);
    let result = execCode(code);
    console.log("Final result");
    console.log(result);

    expr.body.forEach((element) => {
        output.push({
            id: element.id,
            output: result[element.id],
            error: ""
        });
    });
    // expr.body.forEach(element => {
    //     let code = generateCode(element);
    //     let result = execCode(code);

    //     output.push({
    //         id: element.id,
    //         output: result,
    //         error: ""
    //     });
    // });
    console.log(output);

    return {'results': output}
}
