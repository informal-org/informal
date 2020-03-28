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
const BUILTIN_SYMBOLS = {
    "AND": function() {},
    "OR": function() {}, 
    "NOT": function() {},
    "TRUE": true,
    "FALSE": false,
}

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



// Dict, Value -> value | null
export function resolveMember(node, context) {
    // cell4.name.blah
    // { "type": "MemberExpression", "computed": false, 
    // "object": { "type": "MemberExpression", "computed": false, 
        // "object": { "type": "Identifier", "name": "cell4" }, 
        // "property": { "type": "Identifier", "name": "name" } }, 
    // "property": { "type": "Identifier", "name": "blah" } } 
    // Object could be recursive for nested a.b.c style lookup.
    // let object = null;

    // let subnode = node;
    // while(node) {

    // }
    // let object = context.resolve(node.object.name);
    // if(object !== null){
    //     return object.resolve(node.property.name)
    // }
    // console.log(node);
    let object = null;
    if(node.object.type === "MemberExpression"){
        object = resolveMember(node.object, context);
    } else {
        // Assert is identifier
        object = context.resolve(node.object.name);
    }

    // console.log("object is");
    // console.log(object.name);

    if(object !== null){
        return object.resolve(node.property.name);
    }
    return null;
}

function isBoolean(value) {
    let lower = value.toLowerCase();
    return lower == "true" || lower == "false"
}

// Returns cell id
function resolve(state, name, scope) {
    var matches = state.byName[name];
    // TODO: Implement scope resolution
    if(matches !== undefined && matches.length > 0) {
        return matches[0]
    }
    return null
}

export function getDependencies(node, context) {
    /* Parse through an expression tree and return list of dependencies */
    if(node.type === "BinaryExpression") {
        let left = getDependencies(node.left, context)
        let right = getDependencies(node.right, context);
        return left.concat(right);
    } else if(node.type === "UnaryExpression") {
        return getDependencies(node.argument, context);
    } else if(node.type === "Literal") {
        return []
    } else if(node.type === "Identifier") {
        let uname = node.name.toUpperCase();
        if(uname in BUILTIN_SYMBOLS){
            return [];
        }

        // todo LOOKUP NAME
        let id_resolution = resolve(context, node.name, null)
        if(id_resolution !== undefined && id_resolution !== null) {
            return [id_resolution]
        }
        return []
    
    } else if (node.type === "Compound") {
        // a, b
        let deps = [];
        return node.body.map((subnode) => {
            deps.concat(getDependencies(subnode, context))
        });
        return deps;
    } else if (node.type == "ThisExpression") {
        return [];
    } else if(node.type == "MemberExpression") {
        return [resolveMember(node, context)];
    } else if (node.type == "CallExpression") {
        // TODO: Also add function when user definable functions are possible.

        let depArgs = [];
        node.arguments.forEach(subnode => {
            depArgs.concat(getDependencies(subnode, context));
        })

        return depArgs;
    } else {
        console.log("UNHANDLED eval CASE")
        console.log(node);

        // Node.type == Identifier
        // Name lookup
        // TODO: Handle name errors better.
        // TODO: Support [bracket name] syntax for spaces.
        return [context.resolve(node.name)];
    }
}



function computeDeps() {

}

function generateCode(cells) {
    // {id, name, input}
    // TODO: Generate safe names
    // var variable_name = cell.name;

    // return `var ${variable_name} = ${cell.input}; ${cell.input}`;

    var code = `
    function ctx_init() {
        var ctx = {};
        return {
            set: function(k, v) { ctx[k] = v; },
            get: function(k) { return ctx[k]; },
            all: function() { return ctx }
        };
    };
    var ctx = ctx_init();
    `;

    for(var cell_id in cells) {
        var cell = cells[cell_id];
        if(cell.expr !== undefined && cell.expr !== null && cell.expr !== "") {
            console.log(cell);
            var variable_name = cell.name ? cell.name : "a" + cell.id;

            code += `var ${variable_name} = ${cell.expr};\n`;
            code += `ctx.set("${cell.id}", ${variable_name});\n`;
        }

    }

    code += "ctx.all();\n"

    console.log(code);
    return code;
}

function execCode(code) {
    // TODO: Sandboxed execution
    return eval(code);
}


function parse(expr) {
    let parsed = jsep(expr);
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

export function evaluate(state) {
    console.log("Evaluating");
    console.log(state);
    
    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    let cells = state.cellsReducer.byId;
    let parsed = parseAll(cells);

    let code = generateCode(parsed);
    let result = execCode(code);
    console.log("Final result");
    console.log(result);

    for(var cell_id in cells) {
        var element = cells[cell_id];
        output.push({
            id: element.id,
            value: result[element.id],
            error: ""
        });
    }
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
