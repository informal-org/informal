/* 
Compiler / Interpreter which consumes the AST generated by parser
and either evaluates or generates bytecode
*/

import { JS_PRE_CODE, JS_POST_CODE } from "../constants"

const BINARY_OPS = {
    "and": "__aa_and",
    "or": "__aa_or",    
    "+": "__aa_add",
    "-": "__aa_sub",
    "*": "__aa_multiply",
    "/": "__aa_divide",
    "%": "__aa_mod",
    "<": "__aa_lt",
    ">": "__aa_gt",
    "<=": "__aa_lte",
    ">=": "__aa_gte",
    "==": "__aa_eq",
    "!=": "__aa_neq"
}

const UNARY_OPS = {
    "-": "__aa_uminus",
    "not": "__aa_not"
}

class Expr {
    constructor(cell, node) {
        // Store context relevant to this expression type
        this.cell = cell;
        this.node = node;
    }
    emitJS(target, gen) { 
        // Emits a js version of the expression and return a reference to it
        // target: Backend specific code emitter
        // gen: Language specific code generator
        console.log("Emit JS not implemented for " + typeof this);
    }
    evaluate() { 
        // Evaluates the Expression and returns the result
        console.log("Evaluated not implemented for " + typeof this);
    }
    static parse(cell, node) { 
        // Should parse the relevant bits from the node into a structure
        // Returns Expr node of given type
        console.log("Parse not implemented for " + this)
    }
}

class BinaryExpr extends Expr {
    constructor(cell, node, left, right) {
        super(cell, node)
        // Expressions
        this.left = left;
        this.right = right;
        this.operator = BINARY_OPS[node.operator.keyword]
    }
    emitJS(target) {
        let left = this.left.emitJS(target)
        let right = this.right.emitJS(target)
        return target.functionCall(this.operator, left, right)
    }
    static parse(cell, node) {
        let left = astToExpr(cell, node.left)
        let right = astToExpr(cell, node.right)
        return new BinaryExpr(cell, node, left, right);
    }
}

class UnaryExpr extends Expr {
    constructor(cell, node, left) {
        super(cell, node)
        this.left = left
        this.operator = UNARY_OPS[node.operator.keyword]
    }
    
    emitJS(target) {
        let left = this.left.emitJS(target)
        return target.functionCall(this.operator, left);
    }
    static parse(cell, node) {
        let left = astToExpr(cell, node.left)
        return new UnaryExpr(cell, node, left)
    }
}

class LiteralExpr extends Expr {
    constructor(cell, node) {
        super(cell, node);
        // TODO: Type inference
    }
    emitJS(target) {
        return target.literal(this.node.value)
    }
}

class IdentifierExpr extends Expr {
    constructor(cell, node) {
        super(cell, node);
    }
    emitJS(target) {
        return target.identifier(this.node.value)
    }
}

class MapExpr extends Expr {

}

class ArrayExpr extends Expr {
    constructor(cell, node, elements) {
        super(cell, node)
        this.elements = elements;
    }
    emitJS(target) {
        let elements_js = this.elements.map((elem) => elem.emitJS(target))
        return target.functionCall("Stream.array", target.array(elements_js))
    }
    static parse(cell, node) {
        let elements = node.value.map((elem) => astToExpr(cell, elem))
        return new ArrayExpr(cell, node, elements);
    }
}

class FilteringExpr extends Expr {
    constructor(cell, node, arr, filter) {
        super(cell, node);
        this.arr = arr;
        this.filter = filter;
    }

    emitJS(target){
        return target.method(this.arr.emitJS(target), "get", this.filter.emitJS(target))
    }

    static parse(cell, node) {
        let arr = astToExpr(cell, node.left);
        let filter = astToExpr(cell, node.value[0]);
        return new FilteringExpr(cell, node, arr, filter)
    }
}

class InvokeExpr extends Expr {
    // Call/Invoke a "function" ()
    constructor(cell, node, fn, params) {
        super(cell, node);
        this.fn = fn;
        this.params = params;
    }

    emitJS(target) {
        let paramsJS = this.params.map((p) => p.emitJS(target))
        return target.functionCall("__aa_call", this.fn.emitJS(target), ...paramsJS)
    }

    static parse(cell, node) {
        let params = node.value.map((p) => astToExpr(cell, p))
        let fn = astToExpr(cell, node.left);
        return new InvokeExpr(cell, node, fn, params)
    }
}

class ConditionalExpr extends Expr {

}

class LoopExpr extends Expr {

}

class AssignmentExpr extends Expr {

}


class MemberExpr extends Expr {
    // Obj.attr dot access
    constructor(cell, node, obj, attr) {
        super(cell, node);
        this.obj = obj;
        this.attr = attr;
    }

    emitJS(target) {
        // Quote the attribute name.
        return target.functionCall("__aa_attr", this.obj.emitJS(target), "" + this.attr.emitJS(target))
    }

    static parse(cell, node) {
        let obj = astToExpr(cell, node.left);
        let attr = astToExpr(cell, node.right);
        return new MemberExpr(cell, node, obj, attr)
    }

}

// Grouping?
class CodeGen {}
class JSCodeGen extends CodeGen {
    constructor(env) {
        super()
        this.env = env;
        this.variable_count = 0;
        this.code = JS_PRE_CODE;
    }

    functionCall(fn, ...args) {
        return fn + "(" + args.join(",") + ")"
    }

    method(obj, fn, ...args) {
        return obj + "." + fn + "(" + args.join(",") + ")"
    }

    declaration(name, value) {
        return "var " + name + " = " + value;
    }

    literal(value) {
        return JSON.stringify(value)
    }

    identifier(name) {
        return name
    }

    array(elements) {
        return "[" + elements.join(",") + "]"
    }

    newVariable() {
        return "u_" + this.variable_count++;
    }

    emit(newCode) {
        this.code += newCode
    }

    emitTry() {
        this.emit("\ntry {\n");
    }

    emitCatchAll(cell) {
        this.emit(`} catch(err) {
            console.log(err); 
            ctx.setError("${cell.id}", err.message);
        }\n`);
    }
    
    emitCellResult(cell) {
        this.emit("\n");
        this.emit(
            this.functionCall('ctx.set', "" + cell.id, cell.getCellName()) + ";\n")
    }

    emitCellError(cell, error, ...err_args) {
        this.emit(
            this.functionCall(
                "ctx.set", 
                "" + cell.id, 
                this.error(error, ...err_args)
            ) + ";\n"
        )
    }

    error(err, ...args) {
        return "new " + err + "(" + args.join(",") + ")"
    }

    finalize() {
        this.code += JS_POST_CODE;
        return this.code
    }
}

export function astToExpr(cell, node) {
    // console.log("AST TO EXPR OF " + cell.id);
    // console.log(node);
    if(!node || !node.node_type) { return undefined; }
    switch(node.node_type) {
        case "binary":
            return BinaryExpr.parse(cell, node)
        case "unary":
            return UnaryExpr.parse(cell, node)
        case "(literal)":
            return new LiteralExpr(cell, node)
        case "(identifier)":
            return new IdentifierExpr(cell, node)
        case "(grouping)": 
            // Swallow parens - order is explicit in the AST form
            if(node.value.length != 1) { throw SyntaxError("Unexpected Parentheses") }
            return astToExpr(cell, node.value[0])
        case "apply":
            return InvokeExpr.parse(cell, node)
        case "(array)":
            return ArrayExpr.parse(cell, node)
        case "(where)":
            return FilteringExpr.parse(cell, node)
        case "(member)":
            return MemberExpr.parse(cell, node)
        default:
            console.log("Unknown AST node type: " + node.node_type);
        
        
        
    }
}

export function compileJS(env) {
    var target = new JSCodeGen(env);

    env.exprAll(env.root);
    env.emitJS(env.root, target);

    return target.finalize()
}