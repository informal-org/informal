/* Expression evaluation module */
import { Big } from 'big.js';
import * as util from '../utils';
import { castBoolean, isCell, formatValue, unboxVal } from '../utils';
import { Value, Group, Table } from './engine';

// @ts-ignore
var jsep = require("jsep");
Big.RM = 2;     // ROUND_HALF_EVEN - banker's roll


function itemApply(ai: any, bi: any, funcName: string, doFudge: boolean, func?: Function) {
    // Figure out what function to call. 
    let aVal = unboxVal(ai);
    let bVal = unboxVal(bi);
    let result;
    if(func !== undefined){
        result = func(aVal, bVal);
    } else if(typeof aVal == "object" && funcName in aVal){
        // Hack: Convert from big -> Number
        if(funcName == "pow"){
            result = aVal[funcName](Number(bVal.valueOf()))
        } else {
            result = aVal[funcName](bVal);
        }
        
    } else {
        // HACK: Try to map some common functions back.
        if(funcName == "eq"){
            result = aVal === bVal;
        } else if(funcName == "plus") {
            result = aVal + bVal;
        }
    }

    if(doFudge){
        result = util.fudge(result);
    }
    return result;
}

// Create new cells as result, but don't bind or store in all cells list.
// TODO: What about names bound to this later?
function itemwiseApply(aRaw: any, bRaw: any, funcName: string, doFudge=false, func?: Function) {
    let a = unboxVal(aRaw);
    let b = unboxVal(bRaw);

    if(Array.isArray(a) && Array.isArray(b)){   // [a] * [b]
        // ASSERT BOTH ARE SAME LENGTH
        let resultList = a.map(function(ai, i) {
            return new Value(itemApply(ai, b[i], funcName, doFudge, func));
        });
        return resultList;
    }
    else if(Array.isArray(a)) { // [a] * 2
        let resultList = a.map((ai) => {
            return new Value(itemApply(ai, b, funcName, doFudge, func));
        });
        return resultList;

    } else if(Array.isArray(b)) {   // 2 * [a]
        let resultList = b.map((bi) => {
            return new Value(itemApply(a, bi, funcName, doFudge, func));
        });
        return resultList;

    } else {    // 1 + 2 : both are scalar values
        return itemApply(a, b, funcName, doFudge, func);
    }
}

function boolAnd(a: string, b: string) {
    if(util.isFalse(a) || util.isFalse(b)){
        // Return true regardless of type is one is known to be false.
        return false;
    } else if(util.isBoolean(a) && util.isBoolean(b)){
        // Else only evaluate in case of valid boolean values.
        return a && b;
    }
    return undefined;   // TODO: Undefined or null?
}

function boolOr(a: string, b: string) {
    // TODO: The way it's done in python or js to return first true element is useful.
    if(util.isTrue(a) || util.isTrue(b)){
        return true;
    } else if(util.isBoolean(a) && util.isBoolean(b)){
        return a || b;
    }
    return undefined;
}

// Evaluate expression
var BINARY_OPS = {
    // TODO: Should other operations be fudged?
    "+" : (a: Big, b: Big) => { return itemwiseApply(a, b, "plus") },    // a.plus(b)
    "-" : (a: Big, b: Big) => { return itemwiseApply(a, b, "minus"); },
    "*" : (a: Big, b: Big) => { return itemwiseApply(a, b, "times", true); },
    "/" : (a: Big, b: Big) => { return itemwiseApply(a, b, "div", true); },
    "^" : (a: Big, b: Big) => { return itemwiseApply(a, b, "pow"); },
    "MOD" : (a: Big, b: Big) => { return itemwiseApply(a, b, "mod"); },

    "=" : (a: Big, b: Big) => { return itemwiseApply(a, b, "eq");},//
    ">" : (a: Big, b: Big) => { return itemwiseApply(a, b, "gt"); },
    ">=" : (a: Big, b: Big) => { return itemwiseApply(a, b, "gte"); },    // TODO
    "<" : (a: Big, b: Big) => { return itemwiseApply(a, b, "lt"); },
    "<=" : (a: Big, b: Big) => { return itemwiseApply(a, b, "lte"); },

    // "," : (a: Array, b: Array) => {
    //     console.log("Concatenating");
    //     if(Array.isArray(a)){
    //         return a.concat(b);     // Works even if b isn't an array
    //     } else {
    //         return [a].concat(b);
    //     }
    // },

    // TODO: Case insensitive AND, OR, NOT
    // TODO: Array operations on these.
    "AND" : (a: string, b: string) => {
        return itemwiseApply(a, b, "", false, boolAnd);
    },
    "OR" : (a: string, b: string) => {
        return itemwiseApply(a, b, "", false, boolOr);
    },
    "WHERE": (a: Array<any>, b: Array<any>) : Table => {

        let aVal = unboxVal(a);
        if(Array.isArray(aVal) && aVal.length > 0 && aVal[0].type === "group" ){
            // Is array - filter by row for each column.
            return new Table(aVal.map((column, colIndex) => {
                let g = new Group(unboxVal(column).filter((row : Array<any>, rowIndex : number) => {
                    return unboxVal(b[rowIndex]) == true;
                }));
                g.name = column.name;
                return g;
            }));
        }
        return unboxVal(a).filter((aItem : any, aIndex: number) => {
            return unboxVal(b[aIndex]) == true
        })
    }
};


jsep.addBinaryOp("=", 6);
// TODO: Make these case insensitive as well
jsep.addBinaryOp("OR", 1);
jsep.addBinaryOp("AND", 2);
jsep.addBinaryOp("MOD", 10);


jsep.addBinaryOp("WHERE", 0); // Should be evaluated after "=" and other conditionals. So < 6.

jsep.addUnaryOp("NOT"); //  TODO - guess


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


// TODO: Verify is boolean, else typos lead to true.
function unaryNot(a: boolean){
    if(Array.isArray(a)) {
        return a.map((aItem) => {
            return new Value(!unboxVal(aItem));
            // return new Value(!aItem.evaluate(), aItem.env, aItem.name);
        })
    }
    return !unboxVal(a);
}


var UNARY_OPS = {
    "-" : (a: Big) => { return unboxVal(a).times(-1); },
    "NOT" : (a: boolean) => unaryNot(a)
};

export var BUILTIN_FUN = {
    'ROUND': {
        "name": "Round",
        "description": "Round a number",
        "func": Math.round,
        "args": [
            {
                "name": "Number",
                "description": "Number to round",
                "default": ""
            }
        ]
    },
    'SQRT': {
        "name": "Square Root",
        "description": "Find the square root of a number",
        "func": Math.sqrt,
        "args": [
            {
                "name": "Number",
                "description": "Number to sqrt",
                "default": ""
            }
        ]
    }
};


export function resolveMember(node: any, context: Value) : Value|null {
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

// TODO: Test cases to verify operator precedence
// @ts-ignore
export function _do_eval(node, context: Value) {
    if(node.type === "BinaryExpression") {
        let op = node.operator.toUpperCase();
        // console.log("binary op " + node);
        // console.log(node);
        // console.log(node.left)
        // console.log(node.right)
        // if(node.left == false){
        //    return node;
        //}
        // @ts-ignore
        return BINARY_OPS[op](_do_eval(node.left, context), _do_eval(node.right, context));
    } else if(node.type === "UnaryExpression") {
        let op = node.operator.toUpperCase();
        // @ts-ignore
        return UNARY_OPS[op](_do_eval(node.argument, context));
    } else if(node.type === "Literal") {
        return util.castLiteral(node.value);
    } else if(node.type === "Identifier") {
        // Usually boolean's are literals if typed as 'true', but identifiers
        // if case is different.
        let bool = castBoolean(node.name);
        if(bool !== undefined){
            return bool;
        }

        let uname = node.name.toUpperCase();
        if(uname in BUILTIN_FUN) {
            // @ts-ignore
            return BUILTIN_FUN[uname];
        }

        let match = context.resolve(uname);
        // Found the name in an environment

        if(match !== null){
            console.log("lookup of " + uname);
            console.log("match type is " + match.type);
            // return match.evaluate();
            // if(match.type == "value"){
            //     // Values store raw values.
            //     // Other types store aggregate types, which should remain those types.
            //     return match.evaluate();
            // }
            // return match;
            return match.evaluate();
        }
        // TODO: Return as string literal in this case?
        // Probably not - should be lookup error
        // return node.name
        // TODO: Injection check?
        // TOOD: Give nearest match.
        throw node.name + " variable not found";

    } else if (node.type === "Compound") { // a, b
        return node.body.map((subnode) => {
            return _do_eval(subnode, context);
        });
    } else if (node.type === "ThisExpression") {
        console.log(node);
        // Treat "this" as a non-keyword
        return "this"
    } else if (node.type === "MemberExpression") {
        // assert property == Identifier.
        // return node
        return resolveMember(node, context).evaluate();
        
    } else if (node.type == "CallExpression") {​
        let func = _do_eval(node.callee, context);

        let args = [];
        node.arguments.forEach(subnode => {
            let subresult = _do_eval(subnode, context);
            // Wrap scalar constants in a Value so it can be rendered in CellList
            // if(!Array.isArray(subresult) && !isCell(subresult)) {
            //     subresult = new Value("", subresult, env, "");
            // }
            args = args.concat(subresult);
        });

        let result = func.apply(null, args);
        // console.log("Func result");
        // console.log(result);
        return result;
    } else {
        console.log("UNHANDLED eval CASE")
        console.log(node);

        // Node.type == Identifier
        // Name lookup
        // TODO: Handle name errors better.
        // TODO: Support [bracket name] syntax for spaces.
        return context.resolve(node.name).evaluate();
    }
};

// @ts-ignore
export function getDependencies(node, context: Value) : Value[] {
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
        let bool = castBoolean(node.name);
        if(bool != undefined){
            return [];
        }
        let uname = node.name.toUpperCase();
        if(uname in BUILTIN_FUN){
            return [];
        }

        // todo LOOKUP NAME
        return [context.resolve(node.name)]
    
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
    }
    
    else {
        console.log("UNHANDLED eval CASE")
        console.log(node);

        // Node.type == Identifier
        // Name lookup
        // TODO: Handle name errors better.
        // TODO: Support [bracket name] syntax for spaces.
        return [context.resolve(node.name)];
    }
}

// @ts-ignore
export function evaluateExpr(parsed, context: Value) {
    if(parsed != null){
        return _do_eval(parsed, context);
    }
    return null;
}

export function uppercaseKeywords(formula: string) {
    // Convert reserved keywords like "and" to uppercase AND so they can be matched by jsep regardless of case.
    let reserved_words = ["where", "and", "or", "not", "mod"];  // TODO: TRUE, FALSE
    // This could potentially be done in a single regex rather than multiple passes over string
    // but this is good enough for normal sized expressions.
    reserved_words.forEach((keyword) => {
        let keyexp = "(\\W|\^)" + keyword + "(\\W|\$)";
        formula = formula.replace(new RegExp(keyexp, 'gi'), "$1" + keyword.toUpperCase() + "$2");
    })
    return formula;
}


export function parseFormula(expr: string){
    // Assert is formula
    // Return jsep expression
    let formula = expr.substring(1);
    if(util.isDefinedStr(formula)){
        formula = uppercaseKeywords(formula);
        let parsed = jsep(formula);
        return parsed;
    }
    return null;
}

// TODO: Factor this into dependency calculations
export function evaluateStr(strExpr: string, context: Value) {
    let pattern = /{{([^}]+)}}/g;   // Any string in {{ NAME }}
    let match = pattern.exec(strExpr);
    let strResult = strExpr;

    while (match != null) {
        let name = match[1];
        let ref = context.resolve(name);
        if(ref !== null) {
            let refEval = ref.evaluate();
            let value = formatValue(refEval);
            strResult = strResult.replace(new RegExp(match[0], "g"), value);
        }

        match = pattern.exec(strExpr);
    }
    return strResult;
}

// TODO: Refactor duplicate code
export function getStrDependencies(strExpr: string, context: Value) {
    let pattern = /{{([^}]+)}}/g;   // Any string in {{ NAME }}
    let match = pattern.exec(strExpr);
    let strResult = strExpr;
    let deps = [];
    while (match != null) {
        let name = match[1];
        let ref = context.resolve(name);
        if(ref !== null) {
            deps.push(ref);
            // Remove pattern by replacing with empty str
            strResult = strResult.replace(new RegExp(match[0], "g"), "");
        }
        match = pattern.exec(strExpr);
    }
    return deps;
    
}